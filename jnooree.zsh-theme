# Most colors were taken from the robbyrussell's theme:
# https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme

# Enable prompt substitution
setopt promptsubst

if [[ $(uname -s) = *Darwin* ]] && command -v uconv &>/dev/null; then
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
	builtin print -rn -- "$1"$'\a'
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd prompt_current_dir
add-zsh-hook precmd jnr_precmd
add-zsh-hook preexec jnr_preexec

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

# Add support for untracked files
function +vi-git-untracked() {
	if [[ $(git -C "${hook_com[base]}" ls-files \
					-o --exclude-standard --directory --no-empty-directory 2>/dev/null |
				sed -u q | wc -l) -gt 0 ]]; then
		hook_com[misc]="%F{8}?"
	fi
}

function prompt_git() {
	vcs_info
	# This cannot be done by %2v; the color codes don't work at all
	if [[ -n $vcs_info_msg_0_ ]] builtin print -rn -- \
		" %F{blue}(${vcs_info_msg_0_%%:}%F{blue})${vcs_info_msg_1_}"
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
