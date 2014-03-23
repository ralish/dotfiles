# OS X shell configuration

# Prefer GNU coreutils?
USE_GNU_COREUTILS="true"

# Some extra paths to include
export PATH="/usr/local/bin:$PATH"

# Tell ls to be colourful
export CLICOLOR='1'
export LSCOLORS='Exfxcxdxbxegedabagacad'

# Tell grep to highlight matches
export GREP_OPTIONS='--color=auto'

# Load grc if it's present
if [ -f "$(brew --prefix)/etc/grc.bashrc" ]; then
	source "$(brew --prefix)/etc/grc.bashrc"
fi

# Preference GNU coreutils over the system defaults
coreutils_binpath="/usr/local/opt/coreutils/libexec/gnubin"
coreutils_manpath="/usr/local/opt/coreutils/libexec/gnuman"
if [ -n "$USE_GNU_COREUTILS" ]; then
	if [ -d "$coreutils_binpath" ]; then
		export PATH="$coreutils_binpath:$PATH"
		if [ -d "$coreutils_manpath" ]; then
			if [ -n "$MANPATH" ]; then
				export MANPATH="$coreutils_manpath:$MANPATH"
			else
				export MANPATH="$coreutils_manpath"
			fi
		fi
	fi
fi

# Add Python site-packages to path if it's present
python_sitepkgs="/usr/local/lib/python2.7/site-packages"
if [ -d "$python_sitepkgs" ]; then
	if [ -n "$PYTHONPATH" ]; then
		export PYTHONPATH="$python_sitepkgs"
	else
		export PYTHONPATH="$python_sitepkgs:$PYTHONPATH"
	fi
fi

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet
