# Most colors were taken from the robbyrussell's theme:
# https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme

# Enable prompt substitution
setopt promptsubst

function prompt_current_dir() {
	local curr_dir='%~'
	local expanded_curr_dir="${(%)curr_dir}"

	# Show full path of named directories if they are the current directory.
	if [[ $expanded_curr_dir != */* ]]; then
		curr_dir='%/'
		expanded_curr_dir="${(%)curr_dir}"
	fi

	if [[ ${#expanded_curr_dir} -gt $(( COLUMNS - ${MIN_COLUMNS:-30} )) ]]; then
		curr_dir='.../%2d'
		expanded_curr_dir="${(%)curr_dir}"
	fi

	psvar[1]="$expanded_curr_dir"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd prompt_current_dir
# For first pwd
prompt_current_dir

# Some of the code was copied and modified from the examples
# of the official zsh repo:
# https://github.com/zsh-users/zsh/blob/master/Misc/vcs_info-examples
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*+post-backend:*' hooks git-untracked
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr "%F{cyan}+"
zstyle ':vcs_info:*' unstagedstr "%F{yellow}!"
zstyle ':vcs_info:*' formats "%F{red}%b%F{blue}:%c%u%m"
zstyle ':vcs_info:*' actionformats "%F{red}%b%F{blue}:%c%u%m" "%F{magenta}%a"

# Begin overrides
# see https://github.com/zsh-users/zsh/blob/master/Functions/VCS_Info/Backends/VCS_INFO_get_data_git

function VCS_INFO_git_getaction() {
	local gitdir="$1"

	if [[ -e ${gitdir}/BISECT_LOG ]]; then
		gitaction=" <B>"
	elif [[ -e ${gitdir}/MERGE_HEAD ]]; then
		gitaction=" >M<"
	elif [[ -e ${gitdir}/rebase-merge || -e ${gitdir}/rebase-apply ]]; then
		gitaction=" >R>"
	elif [[ -e ${gitdir}/CHERRY_PICK_HEAD ]]; then
		gitaction=" <C<"
	else
		return 1
	fi

	return 0
}

function VCS_INFO_git_getbranch() {
	local ref ahead behind
	local -a gitstatus

	# Exit early in case the worktree is on a detached HEAD
	if ! ref="$(git symbolic-ref -q --short HEAD)"; then
		gitbranch="→ $(git rev-parse --short HEAD)"
		return 0
	fi

	read -r ahead behind < <(
		git rev-list --left-right --count \
			HEAD..."${hook_com[branch]}@{upstream}" 2>/dev/null
	)

	(( ahead )) && gitstatus+=("%F{green}+${ahead}%F{blue}")
	(( behind )) && gitstatus+=("%F{red}-${behind}")

	gitbranch="${ref//\%/%%}${gitstatus:+"%F{blue}:"}${(j:/:)gitstatus}"
	return 0
}

# Don't need patch, etc. information
function VCS_INFO_git_handle_patches() { }
function VCS_INFO_git_map_rebase_line_to_hash_and_subject() { }

# End overrides

# Add support for untracked files
function +vi-git-untracked() {
	if [[ $(git ls-files -o --exclude-standard --directory --no-empty-directory 2>/dev/null |
		sed -u q | wc -l) -gt 0 ]]; then
		hook_com[misc]="%F{8}?"
	fi
}

function prompt_git() {
	if [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) != true ]]; then
		return
	fi

	vcs_info
	# This cannot be done by %2v; the color codes don't work at all
	builtin print -rn -- \
		" %F{blue}(${vcs_info_msg_0_%%:}%F{blue})${vcs_info_msg_1_}"
}

# Now define prompt & rprompt
PROMPT='%B%(?:%F{green}:%F{red})[%F{cyan}%1v%(?:%F{green}:%F{red})]'\
$'$(prompt_git)%f%-50(l::\n%B>)%b '

if [[ $USER != "$DEFAULT_USER" ]]; then
	RPROMPT='%n@%m'
elif [[ -n $SSH_CONNECTION ]]; then
	RPROMPT='@%m'
fi

if [[ -n $RPROMPT ]]; then
	RPROMPT="%B%F{blue}$RPROMPT%f%b"
fi
