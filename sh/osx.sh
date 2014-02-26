# OS X environment shell configuration

# Some extra paths to include
export PATH="/usr/local/bin:$PATH"

# Tell ls to be colourful
export CLICOLOR=1
export LSCOLORS=Exfxcxdxbxegedabagacad

# Tell grep to highlight matches
export GREP_OPTIONS='--color=auto'

# Load grc if it's present
if [ -f "$(brew --prefix)/etc/grc.bashrc" ]; then
	source "$(brew --prefix)/etc/grc.bashrc"
fi

