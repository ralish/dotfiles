# Path to oh-my-zsh configuration
ZSH=$HOME/.oh-my-zsh

# Name of the oh-my-zsh theme to load
ZSH_THEME="gianu"

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
# COMPLETION_WAITING_DOTS="true"

# Disable marking untracked files under VCS as dirty
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Which plugins would you like to load?
plugins=(debian git rand-quote)

# Actually load oh-my-zsh with our settings
source $ZSH/oh-my-zsh.sh

# Load virtualenvwrapper if it is present
if [ -f /etc/bash_completion.d/virtualenvwrapper ]; then
	export WORKON_HOME=$HOME/.virtualenvs
	source /etc/bash_completion.d/virtualenvwrapper
fi

# Customise our path
export PATH=PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games

