# shellcheck shell=sh

# dotnet configuration
if command -v dotnet > /dev/null; then
    dotnet_bin="$HOME/.dotnet/tools"

    # Opt-out of telemetry
    export DOTNET_CLI_TELEMETRY_OPTOUT=true

    # Add global tools to our PATH
    build_path "$dotnet_bin" "$PATH"
    # shellcheck disable=SC2154
    export PATH="$build_path"

    # Additional setup for specific shells
    # shellcheck disable=SC2154
    if [ -n "$BASH" ]; then
        # shellcheck source=/dev/null
        . "$sh_dir/apps/dotnet.bash"
    elif [ -n "$ZSH_NAME" ]; then
        # shellcheck source=/dev/null
        . "$sh_dir/apps/dotnet.zsh"
    fi

    unset dotnet_bin
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
