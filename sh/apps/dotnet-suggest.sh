# shellcheck shell=sh

# dotnet-suggest configuration
if df_app_load 'dotnet-suggest' 'command -v dotnet-suggest > /dev/null'; then
    # Tab completion for System.CommandLine
    # https://learn.microsoft.com/en-au/dotnet/standard/commandline/how-to-enable-tab-completion
    # shellcheck disable=SC2154
    if [ -n "$BASH" ]; then
        # shellcheck source=/dev/null
        . "${sh_dir}/apps/dotnet-suggest.bash"
    elif [ -n "$ZSH_NAME" ]; then
        # shellcheck source=/dev/null
        . "${sh_dir}/apps/dotnet-suggest.zsh"
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
