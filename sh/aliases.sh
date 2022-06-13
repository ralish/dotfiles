# shellcheck shell=sh

# Dummy command for correct scoping of subsequent shellcheck directive
true

# Enable colour support for ls and *grep
# shellcheck disable=SC2154
if [ -n "$LS_COLORS" ] || [ -n "$LSCOLORS" ]; then
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias egrep='egrep --color=auto'
    alias fgrep='fgrep --color=auto'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
