# How to enable tab completion for the .NET CLI
# https://learn.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete#zsh
_dotnet_cli_zsh_complete() {
    local completions=("$(dotnet complete "$words")")

    if [[ -z $completions ]]; then
        _arguments '*::arguments: _normal'
        return
    fi

    # This is not a variable assignment, don't remove spaces!
    _values = "${(ps:\n:)completions}"
}

compdef _dotnet_cli_zsh_complete dotnet

# vim: syntax=zsh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
