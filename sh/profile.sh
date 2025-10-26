# shellcheck shell=sh

# (da)sh
# If invoked as a login shell, reads and executes commands from ~/.profile.
#
# bash
# If invoked as an interactive login shell, or as a non-interactive shell with
# the --login option, looks for and executes the first found of the following:
# - ~/.bash_profile
# - ~/.bash_login
# - ~/.profile
#
# (t)csh
# Not used.
#
# zsh
# Not used.

# Bash specific
if [ -n "$BASH_VERSION" ]; then
    # Source .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        # shellcheck source=sh/profile.sh
        . "$HOME/.bashrc"
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
