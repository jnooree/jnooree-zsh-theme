# Most colors were taken from the robbyrussell's theme:
# https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme

# Enable prompt substitution
setopt promptsubst

if [[ $OSTYPE = darwin* ]] && command -v uconv &>/dev/null; then
	function _jnr_set_dir() {
		psvar[1]="$(builtin print -rn -- "$1" | uconv -x Any-NFC)"
	}
else
	function _jnr_set_dir() {
		psvar[1]="$1"
	}
fi

function _jnr_update_dir() {
	local curr_dir='%~'
	local expanded_curr_dir="${(%)curr_dir}"

	# Show full path of named directories if they are the current directory.
	if [[ $expanded_curr_dir != */* ]]; then
		curr_dir='%/'
		expanded_curr_dir="${(%)curr_dir}"
	fi

	if [[ ${#expanded_curr_dir} -gt $((COLUMNS - ${MIN_COLUMNS:-30})) &&
		${#${(As:/:)expanded_curr_dir#/}} -gt 2 ]]; then
		curr_dir='.../%2d'
		expanded_curr_dir="${(%)curr_dir}"
	fi

	_jnr_set_dir "$expanded_curr_dir"
}
# For first pwd
_jnr_update_dir

function _jnr_precmd() {
	builtin print -Pn '\e]0;%n@%m [%1v]\a'
}

function _jnr_preexec() {
	builtin print -Pn '\e]0;%n@%m: '
	builtin print -rn -- "${(V)1}"$'\a'
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _jnr_update_dir
if [[ $TERM != (dumb|linux) ]]; then
	add-zsh-hook precmd _jnr_precmd
	add-zsh-hook preexec _jnr_preexec
fi

zmodload zsh/system

# Runs git with stdout collected into REPLY; returns 124 on timeout.
function _jnr_git() {
	setopt localoptions no_monitor no_notify no_sh_word_split no_glob_subst

	local -x GIT_OPTIONAL_LOCKS=0
	local -i fd pid ret
	local chunk

	# coproc (unlike <(...)) publishes the child pid in $!.
	coproc git "$@" 2>/dev/null
	pid=$!
	exec {fd}<&p
	REPLY=
	# sysread returns 4 on timeout and 5 on EOF.
	while true; do
		sysread -t ${GIT_PROMPT_TIMEOUT:-1} -i $fd chunk
		ret=$?
		(( ret )) && break
		REPLY+=$chunk
	done
	exec {fd}<&-

	(( ret == 5 )) && return 0
	(( pid > 0 )) && kill $pid 2>/dev/null
	(( ret == 4 )) && return 124
	return 1
}

# Sets _jnr_git_dir and _jnr_git_top; fails outside a repository or in a bare one.
function _jnr_git_locate() {
	setopt localoptions no_sh_word_split no_glob_subst no_ksh_arrays

	local -a info
	_jnr_git rev-parse --absolute-git-dir --is-bare-repository \
		--is-inside-work-tree --show-toplevel || return
	# Outside a work tree --show-toplevel fails, but the three lines before it
	# are already printed, hence >= 3 rather than == 4.
	info=(${(f)REPLY})
	(( $#info >= 3 )) && [[ $info[2] != true ]] || return 1

	_jnr_git_dir=$info[1]
	if [[ $info[3] == true ]]; then
		_jnr_git_top=$info[4]
	else
		# Inside .git: first NUL-separated record is "worktree <main worktree path>".
		_jnr_git worktree list --porcelain -z || return
		_jnr_git_top=${${${(0)REPLY}[1]}#worktree }
	fi
}

function _jnr_git_action() {
	local gitdir=$1
	if [[ -d $gitdir/rebase-apply ]]; then
		if [[ -f $gitdir/rebase-apply/rebasing ]]; then
			REPLY='>R>'
		elif [[ -f $gitdir/rebase-apply/applying ]]; then
			REPLY='>A>'
		else
			REPLY='>R?>'
		fi
	elif [[ -e $gitdir/BISECT_LOG ]]; then
		REPLY='<B>'
	elif [[ -e $gitdir/MERGE_HEAD ]]; then
		REPLY='>M<'
	elif [[ -e $gitdir/rebase-merge ]]; then
		REPLY='>R>'
	elif [[ -e $gitdir/REVERT_HEAD ]]; then
		REPLY='<V|'
	elif [[ -e $gitdir/CHERRY_PICK_HEAD ]]; then
		REPLY='<C<'
	else
		return 1
	fi
}

function _jnr_prompt_git() {
	[[ -n $DISABLE_GIT_PROMPT ]] && return

	setopt localoptions no_sh_word_split no_glob_subst no_ksh_arrays

	local _jnr_git_dir _jnr_git_top
	local -a lines
	_jnr_git_locate && _jnr_git -C $_jnr_git_top status \
		--porcelain=v2 --branch --show-stash --no-renames \
		--ignore-submodules=dirty
	case $? in
		0) lines=(${(f)REPLY}) ;;
		124) builtin print -rn -- ' %F{blue}(%F{yellow}!timeout!%F{blue})'; return ;;
		*) return ;;
	esac
	(( $#lines )) || return

	# [(r)pat] yields the first element matching pat; the rest strips the key.
	local head=${lines[(r)\# branch.head *]#\# branch.head }
	local ab=${lines[(r)\# branch.ab *]#\# branch.ab }
	local stash=${lines[(r)\# stash *]#\# stash }
	local -a marks
	if [[ $head == '(detached)' ]]; then
		_jnr_git -C $_jnr_git_top describe --tags --exact-match HEAD
		local tag=${REPLY%%$'\n'*}
		head="→ ${tag:-${${lines[(r)\# branch.oid *]#\# branch.oid }[1,7]}}"
	elif [[ -n $ab ]]; then
		# ab is "+<ahead> -<behind>"
		local ahead=${${ab#+}%% *} behind=${ab##* -}
		(( ahead )) && marks+=("%F{green}+$ahead")
		(( behind )) && marks+=("%F{red}-$behind")
	else
		marks+=('%F{yellow}±?')
	fi
	[[ -n $stash ]] && marks+=("%F{magenta}↓$stash")

	local flags
	# Entries start with "1 XY" (changed), "2 XY" (renamed), "u XY" (unmerged)
	# or "? " (untracked); X is the index state, Y the work tree state, "." clean.
	# ${(M)arr:#pat} keeps the elements matching pat, so ${#...} counts them.
	local -i staged=${#${(M)lines:#[12] [^.]*}} unstaged=${#${(M)lines:#[12] ?[^.]*}}
	local -i unmerged=${#${(M)lines:#u *}} untracked=${#${(M)lines:#\? *}}
	(( staged )) && flags+="%F{cyan}+$staged"
	(( unstaged )) && flags+="%F{yellow}!$unstaged"
	(( unmerged )) && flags+="%F{red}=$unmerged"
	(( untracked )) && flags+="%F{8}?$untracked"

	# Branch/tag names may contain %, which prompt expansion would eat.
	local info=" %F{blue}(\
%F{red}${head//\%/%%}\
${marks:+"%F{blue}:"}${(j"%F{blue}/")marks}\
${flags:+"%F{blue}:"}$flags\
%F{blue})"
	_jnr_git_action $_jnr_git_dir && info+=" %F{magenta}$REPLY"
	builtin print -rn -- "$info"
}

# Now define prompt & rprompt
PROMPT='${DIRENV_MODIFIER:-}%B%(?:%F{green}:%F{red})[%F{cyan}%1v%(?:%F{green}:%F{red})]'\
$'$(_jnr_prompt_git)%f%-50(l::\n>)%b '

RPROMPT='@%m'
if [[ -n $SLURM_JOB_ID ]]; then
	_jnr_rprompt_color='%F{yellow}'
	RPROMPT='@${SLURMD_NODENAME:-${SLURM_SUBMIT_HOST}}'
elif [[ -n $SSH_CONNECTION ]]; then
	_jnr_rprompt_color='%F{blue}'
else
	_jnr_rprompt_color='%F{green}'
fi

if [[ $USER != "$DEFAULT_USER" ]]; then
	RPROMPT="%n$RPROMPT"
fi

ZLE_RPROMPT_INDENT=0
RPROMPT="%B$_jnr_rprompt_color$RPROMPT%f%b"
