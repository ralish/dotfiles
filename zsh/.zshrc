#!/usr/bin/env zsh

# Load our Oh My Zsh configuration
source "$HOME/dotfiles/zsh/oh-my-zsh.zsh"

# Load our common shell configuration
#
# By default Zsh does *not* perform field splitting on unquoted parameter
# expansions. Temporarily enable this behaviour for compatibility with our
# common shell configuration, which relies on the "typical" shell behaviour.
setopt shwordsplit
source "$HOME/dotfiles/sh/common.sh"
unsetopt shwordsplit

# Disable automatic "cd" to a directory of the same name if the input does not
# match a normal command (disabled by default but enabled by Oh My Zsh).
unsetopt auto_cd

# Disable terminal beep on errors
unsetopt beep

# Create a zkbd compatible hash
typeset -g -A key
key[Insert]="${terminfo[kich1]}"
key[Delete]="${terminfo[kdch1]}"
key[Home]="${terminfo[home]}"
key[End]="${terminfo[kend]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"

# Set Ctrl+Backspace to delete previous word
bindkey '^H' backward-kill-word

# Set Ctrl+Left/Right arrow to move to adjacent word
bindkey "\e[D" backward-word
bindkey "\e[C" forward-word
bindkey "\e[1;2D" backward-word
bindkey "\e[1;2C" forward-word
bindkey "\e[1;5D" backward-word
bindkey "\e[1;5C" forward-word

# Set Insert/Delete to insert/delete characters on line
[[ -n ${key[Insert]} ]] && bindkey "${key[Insert]}" overwrite-mode
[[ -n ${key[Delete]} ]] && bindkey "${key[Delete]}" delete-char

# Set Home/End to jump to beginning/end of line
[[ -n ${key[Home]} ]] && bindkey "${key[Home]}" beginning-of-line
[[ -n ${key[End]} ]] && bindkey "${key[End]}" end-of-line

# Use entered text as prefix for searching command history
[[ -n ${key[Up]} ]] && bindkey "${key[Up]}" history-search-backward
[[ -n ${key[Down]} ]] && bindkey "${key[Down]}" history-search-forward

# Ensure terminal is in application mode when zle is active
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
    function zle-line-init() {
        printf '%s' "${terminfo[smkx]}"
    }

    function zle-line-finish() {
        printf '%s' "${terminfo[rmkx]}"
    }

    zle -N zle-line-init
    zle -N zle-line-finish
fi

# Configure online help
alias run-help &> /dev/null
autoload run-help
if [[ -d /usr/local/share/zsh/help ]]; then
    HELPDIR='/usr/local/share/zsh/help'
elif [[ -d /usr/share/zsh/help ]]; then
    HELPDIR='/usr/share/zsh/help'
fi

# Add custom completions
if [[ -d $HOME/.local/share/zsh/site-functions ]]; then
    fpath=($HOME/.local/share/zsh/site-functions $fpath)
fi

# Source custom functions
zsh_functions_dir="$dotfiles/sh/functions"
if [[ -d $zsh_functions_dir ]]; then
    for zsh_function in $zsh_functions_dir/*.zsh; do
        [[ -e $zsh_function ]] || break
        . "$zsh_function"
    done
fi
unset zsh_functions_dir zsh_function

# vim: syntax=zsh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
