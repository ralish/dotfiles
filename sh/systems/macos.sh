# shellcheck shell=sh

# macOS shell configuration

# Prefer GNU coreutils?
USE_GNU_COREUTILS='true'

# Some extra paths to include
EXTRA_SYS_PATHS='/usr/local/bin'

# -----------------------------------------------------------------------------

# Tell ls to be colourful
export CLICOLOR='1'
export LSCOLORS='Exfxcxdxbxegedabagacad'

# Tell grep to highlight matches
export GREP_OPTIONS='--color=auto'

# Assume x86_64 arch for all compiles
export ARCHFLAGS='-arch x86_64'

# If we defined any extra paths add them
if [ -n "$EXTRA_SYS_PATHS" ]; then
    path_changes_system="$EXTRA_SYS_PATHS"
    export PATH="$path_changes_system:$PATH"
fi

# Load bash completion if it's present
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$(brew --prefix)/etc/bash_completion" ]; then
        # shellcheck source=/dev/null
        source "$(brew --prefix)/etc/bash_completion"
    fi
fi

# Load grc if it's present
if [ -f "$(brew --prefix)/etc/grc.bashrc" ]; then
    # shellcheck source=/dev/null
    source "$(brew --prefix)/etc/grc.bashrc"
fi

# Preference GNU coreutils over the system defaults
coreutils_binpath='/usr/local/opt/coreutils/libexec/gnubin'
coreutils_manpath='/usr/local/opt/coreutils/libexec/gnuman'
if [ -n "$USE_GNU_COREUTILS" ]; then
    if [ -d "$coreutils_binpath" ]; then
        path_changes_system=$(path_add_prefix "$coreutils_binpath" "$path_changes_system")
        export PATH="$path_changes_system:$PATH"
        if [ -d "$coreutils_manpath" ]; then
            MANPATH=$(path_add_prefix "$coreutils_manpath" "$MANPATH")
        fi
    fi
fi

# Add Python site-packages to path if it's present
python_sitepkgs='/usr/local/lib/python2.7/site-packages'
if [ -d "$python_sitepkgs" ]; then
    PYTHONPATH=$(path_add_prefix "$python_sitepkgs" "$PYTHONPATH")
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
