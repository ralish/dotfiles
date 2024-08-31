# shellcheck shell=sh

# exa configuration
if df_app_load 'exa' 'command -v exa > /dev/null'; then
    alias l='exa --binary'

    alias la='exa --binary --all'
    alias lg='exa --binary --git --long'
    alias lr='exa --binary --recurse'
    alias lt='exa --binary --tree'

    alias ll='exa --binary --long'
    alias lla='exa --binary --long --all'
    alias llr='exa --binary --long --recurse'
    alias llt='exa --binary --long --tree'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
