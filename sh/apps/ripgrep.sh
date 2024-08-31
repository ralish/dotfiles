# shellcheck shell=sh

# ripgrep configuration
if command -v rg > /dev/null; then
    # Config file path must be set explicitly
    export RIPGREP_CONFIG_PATH="${HOME}/.ripgreprc"

    # Aliases for common operations
    alias rg-todo="rg 'fixme|hack|todo'"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
