# shellcheck shell=sh

# ripgrep configuration
if command -v rg > /dev/null; then
    # The path to any configuration file must be explicitly provided
    export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
