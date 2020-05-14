# shellcheck shell=bash

# dotnet bash completion
_dotnet_bash_complete() {
    local word="${COMP_WORDS[COMP_CWORD]}"

    local completions
    if ! completions="$(dotnet complete --position "${COMP_POINT}" "${COMP_LINE}" 2> /dev/null)"; then
        completions=''
    fi

    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -W "$completions" -- "$word") )
}

complete -f -F _dotnet_bash_complete dotnet

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
