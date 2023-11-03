# Most colors were taken from the robbyrussell's theme:
# https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme

# Shell colors
autoload -Uz colors && colors
# Enable prompt substitution
setopt promptsubst

if [[ -z "${SHORT_HOST-}" ]]; then
	SHORT_HOST="$(hostname -s)"
fi

function prompt_current_dir() {
	local curr_dir='%~'
	local expanded_curr_dir="${(%)curr_dir}"

	# Show full path of named directories if they are the current directory.
	if [[ "$expanded_curr_dir" != */* ]]; then
		curr_dir='%/'
	elif (( ${#expanded_curr_dir} > $(( $COLUMNS - ${MIN_COLUMNS:-30} )) )); then
		curr_dir='.../%2d'
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
zstyle ':vcs_info:*' stagedstr "%{$fg[cyan]%}+"
zstyle ':vcs_info:*' unstagedstr "%{$fg[yellow]%}!"
zstyle ':vcs_info:*' formats "%m%{$fg[blue]%}:%c%u"
zstyle ':vcs_info:*' actionformats "%m%{$fg[blue]%}:%c%u"

# Don't need patch information
# see https://github.com/zsh-users/zsh/blob/master/Functions/VCS_Info/Backends/VCS_INFO_get_data_git
function VCS_INFO_git_handle_patches() { }

# Add support for untracked files
function +vi-git-untracked() {
	if [[ $(git ls-files -o --exclude-standard --directory --no-empty-directory 2>/dev/null |
		sed -u q | wc -l) -gt 0 ]]; then
		# Bright black (ANSI code 90)
		hook_com[unstaged]+=$'%{\033[90m%}?'
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

	(( $ahead )) && gitstatus+=("%{$fg[green]%}+${ahead}%{$fg[blue]%}")
	(( $behind )) && gitstatus+=("%{$fg[red]%}-${behind}")

	hook_com[misc]="${ref}${gitstatus:+"%{$fg[blue]%}:"}${(j:/:)gitstatus}"
}

function +vi-prompt-git() {
	local mode repo_path vcs_info_result

	# exit if not in a git repo
	if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]]; then
		return
	fi

	vcs_info
	vcs_info_result="${vcs_info_msg_0_%%:}"

	repo_path="$(git rev-parse --git-dir 2>/dev/null)"
	if [[ -e "${repo_path}/BISECT_LOG" ]]; then
		mode=" <B>"
	elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
		mode=" >M<"
	elif [[ -e $repo_path/rebase-merge || -e $repo_path/rebase-apply ]]; then
		mode=" >R>"
	fi

	print -n " %{$fg_bold[blue]%}(%{$fg[red]%}${vcs_info_result}\
%{$fg_bold[blue]%})%{$fg[magenta]%}${mode}%{$reset_color%}"
}

# Now define prompt & rprompt
PROMPT="\
%(?:%{$fg_bold[green]%}:%{$fg_bold[red]%})[\
%{$fg[cyan]%}\$(prompt_current_dir)\
%(?:%{$fg_bold[green]%}:%{$fg_bold[red]%})]\
%{$reset_color%}\$(+vi-prompt-git)%-50(l::"$'\n'"%B>%b) "

if [[ "$USER" != "$DEFAULT_USER" ]]; then
	RPROMPT+="${USER}@${SHORT_HOST}"
elif [[ -n "$SSH_CONNECTION" ]]; then
	RPROMPT="@${SHORT_HOST}"
fi

if [[ -n "$RPROMPT" ]]; then
	RPROMPT="%{$fg_bold[blue]%}$RPROMPT%{$reset_color%}"
fi
