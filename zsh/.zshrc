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
plugins=(debian git rand-quote)

# Actually load oh-my-zsh with our settings
source "$ZSH/oh-my-zsh.sh"

# Load our common shell configuration
source "$SHCFG"

# Load virtualenvwrapper if it is present
if [ -f /etc/bash_completion.d/virtualenvwrapper ]; then
	export WORKON_HOME="$HOME/.virtualenvs"
	source /etc/bash_completion.d/virtualenvwrapper
fi

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet
