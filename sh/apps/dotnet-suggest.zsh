# dotnet-suggest-shim.zsh
# https://github.com/dotnet/command-line-api/blob/main/src/System.CommandLine.Suggest/dotnet-suggest-shim.zsh

_dotnet_suggest_zsh_complete() {
    local cmd_path="$(which "${words[1]}")"
    local cmd_line="$words"

    local completions="$(dotnet suggest get --executable "$cmd_path" -- "$cmd_line")"
    local suggestions=(${(f)completions})

    _values 'suggestions' $suggestions
}

compdef _dotnet_suggest_zsh_complete $(dotnet-suggest list)
export DOTNET_SUGGEST_SCRIPT_VERSION='1.0.0'

# vim: syntax=zsh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
