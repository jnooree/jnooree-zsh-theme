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

	(( ahead )) && gitstatus+=("%F{green}+${ahead}")
	(( behind )) && gitstatus+=("%F{red}-${behind}")

	if stashcnt="$(git rev-list -g --count refs/stash -- 2>/dev/null)"; then
		gitstatus+=("%F{magenta}↓${stashcnt}")
	fi

	gitbranch="${ref//\%/%%}${gitstatus:+"%F{blue}:"}${(j"%F{blue}/")gitstatus}"
	return 0
}

# VCS_INFO_get_data_git function was copied and modified from:
# https://github.com/zsh-users/zsh/blob/d8a3bff4f5b4d3df42de8f03adc70f8d0721398f/Functions/VCS_Info/Backends/VCS_INFO_get_data_git
#
# The Z Shell is copyright (c) 1992-2017 Paul Falstad, Richard Coleman,
# Zoltán Hidvégi, Andrew Main, Peter Stephenson, Sven Wischnowsky, and
# others.  All rights reserved.  Individual authors, whether or not
# specifically named, retain copyright in all changes; in what follows, they
# are referred to as `the Zsh Development Group'.  This is for convenience
# only and this body has no legal status.  The Z shell is distributed under
# the following licence; any provisions made in individual files take
# precedence.
#
# Permission is hereby granted, without written agreement and without
# licence or royalty fees, to use, copy, modify, and distribute this
# software and to distribute modified versions of this software for any
# purpose, provided that the above copyright notice and the following
# two paragraphs appear in all copies of this software.
#
# In no event shall the Zsh Development Group be liable to any party for
# direct, indirect, special, incidental, or consequential damages arising out
# of the use of this software and its documentation, even if the Zsh
# Development Group have been advised of the possibility of such damage.
#
# The Zsh Development Group specifically disclaim any warranties, including,
# but not limited to, the implied warranties of merchantability and fitness
# for a particular purpose.  The software provided hereunder is on an "as is"
# basis, and the Zsh Development Group have no obligation to provide
# maintenance, support, updates, enhancements, or modifications.
function VCS_INFO_get_data_git() {
	setopt localoptions extendedglob NO_shwordsplit
	local gitdir gitbase gitbranch gitaction gitunstaged gitstaged gitsha1 gitmisc
	local -i querystaged queryunstaged
	local -a git_patches_applied git_patches_unapplied
	local -A hook_com

	gitdir=${vcs_comm[gitdir]}
	VCS_INFO_git_getbranch ${gitdir}
	gitbase=${vcs_comm[basedir]}
	if [[ -z ${gitbase} ]]; then
		# Bare repository
		gitbase=${gitdir:P}
	fi
	rrn=${gitbase:t}

	if [[ -z ${gitdir} ]] || [[ -z ${gitbranch} ]] ; then
		return 1
	fi

	if zstyle -t ":vcs_info:${vcs}:${usercontext}:${rrn}" "check-for-changes" ; then
		querystaged=1
		queryunstaged=1
	elif zstyle -t ":vcs_info:${vcs}:${usercontext}:${rrn}" "check-for-staged-changes" ; then
		querystaged=1
	fi
	if (( queryunstaged )) ; then
		${vcs_comm[cmd]} diff --no-ext-diff --ignore-submodules=dirty --quiet --exit-code 2> /dev/null ||
			gitunstaged=1
	fi
	if (( querystaged )) ; then
		if ${vcs_comm[cmd]} rev-parse --quiet --verify HEAD &> /dev/null; then
			${vcs_comm[cmd]} diff-index --cached --quiet --ignore-submodules=dirty HEAD 2> /dev/null
			(( $? && $? != 128 )) && gitstaged=1
		else
			# empty repository (no commits yet)
			# 4b825dc642cb6eb9a060e54bf8d69288fbee4904 is the git empty tree.
			${vcs_comm[cmd]} diff-index --cached --quiet --ignore-submodules=dirty 4b825dc642cb6eb9a060e54bf8d69288fbee4904 2>/dev/null
			(( $? && $? != 128 )) && gitstaged=1
		fi
	fi

	VCS_INFO_adjust
	VCS_INFO_git_getaction ${gitdir}

	gitmisc=''

	backend_misc[patches]="${gitmisc}"
	VCS_INFO_formats "${gitaction}" "${gitbranch}" "${gitbase}" \
		"${gitstaged}" "${gitunstaged}" "${gitsha1}" "${gitmisc}"
	return 0
}

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
$'$(prompt_git)%f%-50(l::\n>)%b '


if [[ $USER != "$DEFAULT_USER" ]]; then
	RPROMPT='%n@%m'
elif [[ -n $SSH_CONNECTION ]]; then
	RPROMPT='@%m'
fi

if [[ -n $RPROMPT ]]; then
	ZLE_RPROMPT_INDENT=0
	RPROMPT="%B%F{blue}$RPROMPT%f%b"
fi
