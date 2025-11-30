# shellcheck shell=sh

df_log 'Loading shell aliases ...'

# Enable colour support for ls and *grep
# shellcheck disable=SC2154
if [ -n "$LS_COLORS" ] || [ -n "$LSCOLORS" ]; then
    alias ls='ls --color=auto'

    if command -v diff > /dev/null; then
        alias diff='diff --color=auto'
    fi

    if command -v grep > /dev/null; then
        alias grep='grep --color=auto'
        alias egrep='egrep --color=auto'
        alias fgrep='fgrep --color=auto'
    fi

    if command -v ip > /dev/null; then
        alias ip='ip --color=auto'
    fi
fi

# Git functions
alias gita='git-repo-invoke'
alias gits='git-repo-summary'

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
