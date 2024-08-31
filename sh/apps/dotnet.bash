# shellcheck shell=bash

function _dotnet_cli_bash_complete() {
    local candidates word
    word="${COMP_WORDS[COMP_CWORD]}"
    local IFS=$'\n'

    # shellcheck disable=SC2312
    read -d '' -ra candidates < <(dotnet complete --position "${COMP_POINT}" "${COMP_LINE}" 2> /dev/null)
    # shellcheck disable=SC2312
    read -d '' -ra COMPREPLY < <(compgen -W "${candidates[*]:-}" -- "$word")
}

complete -f -F _dotnet_cli_bash_complete dotnet

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
