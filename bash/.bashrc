#!/usr/bin/env bash

# Consult the Bash Reference Manual for all the details:
# https://www.gnu.org/software/bash/manual/bashref.html

# If we're not running interactively then bail out
[[ -z $PS1 ]] && return

###########################
### Optional Behaviours ###
###########################

# Assume "cd" if the command matches a directory name
#shopt -s autocd

# Assume arguments to "cd" which don't match a directory refer to a variable
#shopt -s cdable_vars

# Autocorrect typos when changing path with "cd"
shopt -s cdspell

# Check if hashed commands exist before executing
shopt -s checkhash

# Check for stopped or running jobs before exiting
shopt -s checkjobs

# Update the window size after every command
shopt -s checkwinsize

# Try and save multi-line commands as a single entry
shopt -s cmdhist

# Replace directory names with results of word expansion
shopt -s direxpand

# Try to autocorrect typos during directory completion
shopt -s dirspell

# Include hidden files and directories in expansion
#shopt -s dotglob

# Enable extended pattern matching features
shopt -s extglob

# Enable support for recursive globbing via "**"
shopt -s globstar

# Append to the history file instead of overwriting
shopt -s histappend

# Allow filename patterns matching no files to expand to a null string
#shopt -s nullglob


#########################
### Control Variables ###
#########################

# Colon-separated list of directories used as a search path for "cd"
#CDPATH="."

# Maximum number of commands to retain in the history
HISTSIZE=250000

# Maximum number of lines to retain in the history
HISTFILESIZE=5000

# Save the time each command was issued & display in this format
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "

# Don't insert duplicate commands or lines with a leading space
HISTCONTROL="ignoredups:ignorespace"

# Patterns matched against commands to be excluded from saving
HISTIGNORE="bg:clear:exit:fg:history"

# Save each command to the history before displaying the subsequent prompt
PROMPT_COMMAND="history -a"

# Number of trailing directories to retain (subject to the prompt string)
#PROMPT_DIRTRIM=2


####################
### Prompt Setup ###
####################

# Default to using a colour prompt for terminal types we know are compatible
case "$TERM" in
    *-256color|xterm-color) colour_prompt=yes ;;
esac

# Force usage of a colour prompt (we'll still sanity check the terminal)
force_colour_prompt=no

# If we elected to force a colour prompt check the terminal can support it
if [[ $force_colour_prompt == "yes" ]]; then
    if [[ -x /usr/bin/tput ]] && tput setaf 1 >& /dev/null; then
        colour_prompt=yes
    fi
fi

# Configure the prompt appropriately (colour if requested & Git if available)
if [[ -n $colour_prompt ]]; then
    if [[ -f /etc/bash_completion.d/git-prompt || -f /etc/bash_completion.d/git ]]; then
        PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\$(__git_ps1)\[\033[00m\]\$ "
    else
        PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
    fi
elif [[ -f /etc/bash_completion.d/git-prompt || -f /etc/bash_completion.d/git ]]; then
    PS1="\u@\h:\w\$(__git_ps1)\$ "
else
    PS1="\u@\h:\w\$ "
fi
unset colour_prompt force_colour_prompt


####################
### Window Setup ###
####################

# Set the window title to "user@host:dir" if this is an xterm or rxvt terminal
case "$TERM" in
    xterm*|rxvt*) PS1="\[\e]0;\u@\h: \w\a\]$PS1" ;;
esac


##########################
### Command Completion ###
##########################

# Enable more powerful command completion if available
if [[ -f /etc/bash_completion ]] && ! shopt -oq posix; then
    # shellcheck source=/dev/null
    source /etc/bash_completion
fi

# Typing "!!<space>" will replace "!!" with the previous command
bind Space:magic-space


##########################
### Common Shell Setup ###
##########################

# Load our common shell configuration
# shellcheck source=sh/common.sh
source "$HOME/dotfiles/sh/common.sh"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
