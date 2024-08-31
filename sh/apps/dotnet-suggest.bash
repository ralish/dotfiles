# shellcheck shell=bash

# dotnet-suggest-shim.bash
# https://github.com/dotnet/command-line-api/blob/main/src/System.CommandLine.Suggest/dotnet-suggest-shim.bash

function _dotnet_suggest_bash_complete() {
    local cmd_path completions suggestions word

    cmd_path="$(type -p "${COMP_WORDS[0]}")"
    completions="$(dotnet-suggest get --executable "$cmd_path" --position "$COMP_POINT" -- "$COMP_LINE")"

    word="${COMP_WORDS[COMP_CWORD]}"
    local IFS=$'\n'
    # shellcheck disable=SC2207
    suggestions=($(compgen -W "$completions" -- "$word"))

    for i in "${!suggestions[@]}"; do
        suggestions[i]="$(printf '%q' "${suggestions[$i]}")"
    done

    COMPREPLY=("${suggestions[@]}")
}

function _dotnet_suggest_bash_register_complete() {
    if command -v dotnet-suggest &> /dev/null; then
        local IFS=$'\n'
        # shellcheck disable=SC2046,SC2312
        complete -F _dotnet_suggest_bash_complete $(dotnet-suggest list)
    fi
}

_dotnet_suggest_bash_register_complete
export DOTNET_SUGGEST_SCRIPT_VERSION='1.0.3'

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
