# Most colors were taken from the robbyrussell's theme:
# https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme

# Shell colors
autoload -Uz colors && colors
# Enable prompt substitution
setopt promptsubst

function prompt_current_dir() {
	local curr_dir='%~'
	local expanded_curr_dir="${(%)curr_dir}"

	# Show full path of named directories if they are the current directory.
	if [[ $expanded_curr_dir != */* ]]; then
		curr_dir='%/'
		expanded_curr_dir="${(%)curr_dir}"
	elif [[ ${#expanded_curr_dir} -gt $(( COLUMNS - ${MIN_COLUMNS:-30} )) ]]; then
		curr_dir='.../%2d'
		expanded_curr_dir="${(%)curr_dir}"
	fi

	print -n "$curr_dir"
}

# Related to git info
# Some of the code was copied and modified from the examples
# of the official zsh repo:
# https://github.com/zsh-users/zsh/blob/master/Misc/vcs_info-examples
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked git-ref-ahead-behind
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr "%F{cyan}+"
zstyle ':vcs_info:*' unstagedstr "%F{yellow}!"
zstyle ':vcs_info:*' formats "%m%F{blue}:%c%u"
zstyle ':vcs_info:*' actionformats "%m%F{blue}:%c%u"

# Don't need patch information
# see https://github.com/zsh-users/zsh/blob/master/Functions/VCS_Info/Backends/VCS_INFO_get_data_git
function VCS_INFO_git_handle_patches() {
	:
}

# Add support for untracked files
function +vi-git-untracked() {
	if [[ $(git ls-files -o --exclude-standard --directory --no-empty-directory 2>/dev/null |
		sed -u q | wc -l) -gt 0 ]]; then
		hook_com[unstaged]+='%F{8}?'
	fi
}

# Add ref info and count for ahead/behind commits vs upstream
function +vi-git-ref-ahead-behind() {
	local ref ahead behind
	local -a gitstatus

	# Exit early in case the worktree is on a detached HEAD
	if ! ref="$(git symbolic-ref -q --short HEAD)"; then
		hook_com[misc]="→ $(git rev-parse --short HEAD)"
		return
	fi

	read -r ahead behind < <(
		git rev-list --left-right --count \
			HEAD..."${hook_com[branch]}@{upstream}" 2>/dev/null
	)

	(( ahead )) && gitstatus+=("%F{green}+${ahead}%F{blue}")
	(( behind )) && gitstatus+=("%F{red}-${behind}")

	hook_com[misc]="\
${ref//\%/%%}${gitstatus:+"%F{blue}:"}${(j:/:)gitstatus}"
}

function +vi-prompt-git() {
	local mode repo_path vcs_info_result

	# exit if not in a git repo
	if [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) != true ]]; then
		return
	fi

	vcs_info
	vcs_info_result="${vcs_info_msg_0_%%:}"

	repo_path="$(git rev-parse --git-dir 2>/dev/null)"
	if [[ -e $repo_path/BISECT_LOG ]]; then
		mode=" <B>"
	elif [[ -e $repo_path/MERGE_HEAD ]]; then
		mode=" >M<"
	elif [[ -e $repo_path/rebase-merge || -e $repo_path/rebase-apply ]]; then
		mode=" >R>"
	fi

	print -n " %F{blue}(%F{red}${vcs_info_result}%F{blue})%F{magenta}${mode}"
}

# Now define prompt & rprompt
PROMPT='%B%(?:%F{green}:%F{red})[%F{cyan}$(prompt_current_dir)'\
$'%(?:%F{green}:%F{red})]$(+vi-prompt-git)%f%-50(l::\n%B>)%b '

if [[ $USER != "$DEFAULT_USER" ]]; then
	RPROMPT='%n@%m'
elif [[ -n $SSH_CONNECTION ]]; then
	RPROMPT='@%m'
fi

if [[ -n $RPROMPT ]]; then
	RPROMPT="%B%F{blue}$RPROMPT%f%b"
fi
