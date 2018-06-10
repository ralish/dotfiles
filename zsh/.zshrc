#!/usr/bin/env zsh

# Path to oh-my-zsh configuration
ZSH="$HOME/.oh-my-zsh"

# Path to our common shell configuration
SHCFG="$HOME/dotfiles/sh/common.sh"

# Name of the oh-my-zsh theme to load
ZSH_THEME="agnoster"

# Used by agnoster theme to hide default user
DEFAULT_USER="sdl"

# Enable case-sensitive completion
CASE_SENSITIVE="true"

# Disable automatic update checks
DISABLE_AUTO_UPDATE="true"

# How often auto-update checks occur
# export UPDATE_ZSH_DAYS=13

# Disable colors in ls
# DISABLE_LS_COLORS="true"

# Disable autosetting terminal title
# DISABLE_AUTO_TITLE="true"

# Disable command autocorrection
DISABLE_CORRECTION="true"

# Display red dots while waiting
COMPLETION_WAITING_DOTS="true"

# Disable marking untracked files under VCS as dirty
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Which plugins would you like to load?
plugins=(colored-man-pages)

# Actually load oh-my-zsh with our settings
source "$ZSH/oh-my-zsh.sh"

# Load our common shell configuration
#
# By default zsh does *not* perform field splitting on unquoted parameter
# expansions. We temporarily enable this option for compatibility with our
# common shell configuration as most shells default to this behaviour.
setopt shwordsplit
source "$SHCFG"
unsetopt shwordsplit

# Create a zkbd compatible hash populating it via the terminfo array
typeset -g -A key
key[Insert]=${terminfo[kich1]}
key[Delete]=${terminfo[kdch1]}
key[Home]=${terminfo[home]}
key[End]=${terminfo[kend]}
key[PageUp]=${terminfo[kpp]}
key[PageDown]=${terminfo[knp]}
key[Up]=${terminfo[kcuu1]}
key[Down]=${terminfo[kcud1]}
key[Left]=${terminfo[kcub1]}
key[Right]=${terminfo[kcuf1]}

# Set Insert/Delete keys to insert/delete chars on line
[[ -n ${key[Insert]} ]] && bindkey "${key[Insert]}" overwrite-mode
[[ -n ${key[Delete]} ]] && bindkey "${key[Delete]}" delete-char

# Set Home/End keys to jump to beginning/end of line
[[ -n ${key[Home]} ]] && bindkey "${key[Home]}" beginning-of-line
[[ -n ${key[End]} ]] && bindkey "${key[End]}" end-of-line

# Use any entered text as the prefix for searching command history
[[ -n ${key[Up]} ]] && bindkey "${key[Up]}" history-search-backward
[[ -n ${key[Down]} ]] && bindkey "${key[Down]}" history-search-forward

# Set Ctrl+Left-arrow/Ctrl+Right-arrow to move to adjacent word
bindkey "\e[D" backward-word
bindkey "\e[C" forward-word
bindkey "\e[1;2D" backward-word
bindkey "\e[1;2C" forward-word
bindkey "\e[1;5D" backward-word
bindkey "\e[1;5C" forward-word

# Make sure the terminal is in application mode when zle is active
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
    function zle-line-init () {
        printf '%s' "${terminfo[smkx]}"
    }
    function zle-line-finish () {
        printf '%s' "${terminfo[rmkx]}"
    }
    zle -N zle-line-init
    zle -N zle-line-finish
fi

# Configure online help for zsh
alias run-help &> /dev/null
autoload run-help
if [ -d "/usr/share/zsh/help" ]; then
    HELPDIR="/usr/share/zsh/help"
elif [ -d "/usr/local/share/zsh/help" ]; then
    HELPDIR="/usr/local/share/zsh/help"
fi

# Load virtualenvwrapper if it is present
if [ -f /etc/bash_completion.d/virtualenvwrapper ]; then
    export WORKON_HOME="$HOME/.virtualenvs"
    source /etc/bash_completion.d/virtualenvwrapper
fi

# Include any custom functions
zsh_functions_dir="$dotfiles/sh/functions"
if [ -d "$zsh_functions_dir" ]; then
    for zsh_function in $zsh_functions_dir/*.zsh; do
        [ -e "$zsh_function" ] || break
        . "$zsh_function"
    done
fi
unset zsh_function zsh_functions_dir

# vim: syntax=zsh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
