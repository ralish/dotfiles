# shellcheck shell=bash

# Tab completion for System.CommandLine
# https://learn.microsoft.com/en-us/dotnet/standard/commandline/tab-completion
export DOTNET_SUGGEST_SCRIPT_VERSION='1.0.2'

function _dotnet_suggest_bash_complete() {
    local cmd_path comp_line_escaped completions

    cmd_path="$(type -p "${COMP_WORDS[0]}")"
    comp_line_escaped="${COMP_LINE//\"/\\\"}"
    completions="$(dotnet-suggest get --executable "$cmd_path" --position "$COMP_POINT" -- "$comp_line_escaped")"

    local IFS=$'\n'
    # shellcheck disable=SC2207
    local suggestions=($(compgen -W "$completions"))

    if [[ ${#suggestions[@]} == 1 ]]; then
        local number="${suggestions[0]/%\ */}"
        COMPREPLY=("$number")
    else
        for i in "${!suggestions[@]}"; do
            suggestions[i]="$(printf '%*s' "-$COLUMNS" "${suggestions[$i]}")"
        done

        COMPREPLY=("${suggestions[@]}")
    fi
}

function _dotnet_suggest_bash_register() {
    local IFS=$'\n'
    # shellcheck disable=SC2046,SC2312
    complete -F _dotnet_suggest_bash_complete $(dotnet-suggest list)
}

_dotnet_suggest_bash_register
unset -f _dotnet_suggest_bash_register

# vim: syntax=bash cc=80 tw=79 ts=4 sw=4 sts=4 et sr
