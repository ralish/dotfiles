# shellcheck shell=sh

# .NET CLI configuration
if df_app_load 'dotnet' 'command -v dotnet > /dev/null'; then
    dotnet_bin="${HOME}/.dotnet/tools"

    # Opt-out of telemetry
    export DOTNET_CLI_TELEMETRY_OPTOUT=true

    # Add global tools to PATH
    build_path "$dotnet_bin" "$PATH"
    # shellcheck disable=SC2154
    export PATH="$build_path"

    # How to enable tab completion for the .NET CLI
    # https://learn.microsoft.com/en-au/dotnet/core/tools/enable-tab-autocomplete
    # shellcheck disable=SC2154
    if [ -n "$BASH" ]; then
        # shellcheck source=/dev/null
        . "${sh_dir}/apps/dotnet.bash"
    elif [ -n "$ZSH_NAME" ]; then
        # shellcheck source=/dev/null
        . "${sh_dir}/apps/dotnet.zsh"
    fi

    unset dotnet_bin
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
