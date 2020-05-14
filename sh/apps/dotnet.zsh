# dotnet zsh completion
_dotnet_zsh_complete() {
    local completions=( "$(dotnet complete "$words")" )

    reply=( "${(ps:\n:)completions}" )
}

compctl -K _dotnet_zsh_complete dotnet

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
