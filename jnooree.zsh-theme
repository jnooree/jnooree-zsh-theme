# Most colors were taken from the robbyrussell's theme:
# https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme

# Enable prompt substitution
setopt promptsubst

if [[ $OSTYPE = darwin* ]] && command -v uconv &>/dev/null; then
	function __prompt_update() {
		psvar[1]="$(builtin print -rn -- "$1" | uconv -x Any-NFC)"
	}
else
	function __prompt_update() {
		psvar[1]="$1"
	}
fi

function prompt_current_dir() {
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

	__prompt_update "$expanded_curr_dir"
}
# For first pwd
prompt_current_dir

function jnr_precmd() {
	builtin print -Pn '\e]0;%n@%m [%1v]\a'
}

function jnr_preexec() {
	builtin print -Pn '\e]0;%n@%m: '
	builtin print -rn -- "${(V)1}"$'\a'
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd prompt_current_dir
if [[ $TERM != (dumb|linux) ]]; then
	add-zsh-hook precmd jnr_precmd
	add-zsh-hook preexec jnr_preexec
fi

zmodload zsh/system

# Runs git with stdout collected into REPLY; returns 124 on timeout.
function jnr_git() {
	setopt localoptions no_monitor no_notify
	local -x GIT_OPTIONAL_LOCKS=0
	local -i fd pid ret
	local chunk

	coproc git "$@" 2>/dev/null
	pid=$!
	exec {fd}<&p
	REPLY=
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

# Sets jnr_git_dir and jnr_git_top; fails outside a repository or in a bare one.
function jnr_git_locate() {
	local -a info
	jnr_git rev-parse --absolute-git-dir --is-bare-repository \
		--is-inside-work-tree --show-toplevel || return
	info=(${(f)REPLY})
	(( $#info >= 3 )) && [[ $info[2] != true ]] || return 1

	jnr_git_dir=$info[1]
	if [[ $info[3] == true ]]; then
		jnr_git_top=$info[4]
	else
		jnr_git worktree list --porcelain -z || return
		jnr_git_top=${${${(0)REPLY}[1]}#worktree }
	fi
}

function jnr_git_action() {
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

function prompt_git() {
	[[ -n $DISABLE_GIT_PROMPT ]] && return

	local jnr_git_dir jnr_git_top
	local -a lines
	jnr_git_locate && jnr_git -C $jnr_git_top status \
		--porcelain=v2 --branch --show-stash --no-renames \
		--ignore-submodules=dirty
	case $? in
		0) lines=(${(f)REPLY}) ;;
		124) builtin print -rn -- ' %F{blue}(%F{red}timeout%F{blue})'; return ;;
		*) return ;;
	esac
	(( $#lines )) || return

	local head=${lines[(r)\# branch.head *]#\# branch.head }
	local ab=${lines[(r)\# branch.ab *]#\# branch.ab }
	local stash=${lines[(r)\# stash *]#\# stash }
	local -a marks
	if [[ $head == '(detached)' ]]; then
		jnr_git -C $jnr_git_top describe --tags --exact-match HEAD
		local tag=${REPLY%%$'\n'*}
		head="→ ${tag:-${${lines[(r)\# branch.oid *]#\# branch.oid }[1,7]}}"
	elif [[ -n $ab ]]; then
		local ahead=${${ab#+}%% *} behind=${ab##* -}
		(( ahead )) && marks+=("%F{green}+$ahead")
		(( behind )) && marks+=("%F{red}-$behind")
	else
		marks+=('%F{yellow}±?')
	fi
	[[ -n $stash ]] && marks+=("%F{magenta}↓$stash")

	local flags
	local -i staged=${#${(M)lines:#[12] [^.]*}} unstaged=${#${(M)lines:#[12] ?[^.]*}}
	local -i unmerged=${#${(M)lines:#u *}} untracked=${#${(M)lines:#\? *}}
	(( staged )) && flags+="%F{cyan}+$staged"
	(( unstaged )) && flags+="%F{yellow}!$unstaged"
	(( unmerged )) && flags+="%F{red}=$unmerged"
	(( untracked )) && flags+="%F{8}?$untracked"

	local info="%F{red}${head//\%/%%}"
	local sep="%F{blue}/"
	(( $#marks )) && info+="%F{blue}:${(pj.$sep.)marks}"
	[[ -n $flags ]] && info+="%F{blue}:$flags"
	jnr_git_action $jnr_git_dir && info+="%F{blue}) %F{magenta}$REPLY" || info+='%F{blue})'
	builtin print -rn -- " %F{blue}($info"
}

# Now define prompt & rprompt
PROMPT='${DIRENV_MODIFIER:-}%B%(?:%F{green}:%F{red})[%F{cyan}%1v%(?:%F{green}:%F{red})]'\
$'$(prompt_git)%f%-50(l::\n>)%b '

if [[ -n $SLURM_JOB_ID ]]; then
	rprompt_color='%F{yellow}'
	RPROMPT='@${SLURMD_NODENAME:-${SLURM_SUBMIT_HOST}}'
elif [[ -n $SSH_CONNECTION ]]; then
	rprompt_color='%F{blue}'
	RPROMPT='@%m'
else
	rprompt_color='%F{green}'
	RPROMPT='@%m'
fi

if [[ $USER != "$DEFAULT_USER" ]]; then
	RPROMPT="%n$RPROMPT"
fi

ZLE_RPROMPT_INDENT=0
RPROMPT="%B$rprompt_color$RPROMPT%f%b"
