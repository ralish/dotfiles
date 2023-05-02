# shellcheck shell=bash

# How to enable tab completion for the .NET CLI
# https://learn.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete#bash
function _dotnet_cli_bash_complete() {
    local IFS=$'\n'
    local candidates

    # shellcheck disable=SC2312
    read -d '' -ra candidates < <(dotnet complete --position "${COMP_POINT}" "${COMP_LINE}" 2> /dev/null)
    # shellcheck disable=SC2312
    read -d '' -ra COMPREPLY < <(compgen -W "${candidates[*]:-}" -- "${COMP_WORDS[COMP_CWORD]}")
}

complete -F _dotnet_cli_bash_complete dotnet

# vim: syntax=bash cc=80 tw=79 ts=4 sw=4 sts=4 et sr
