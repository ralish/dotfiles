# shellcheck shell=sh

# Cabal configuration
if command -v cabal > /dev/null; then
    cabal_bin="$HOME/.cabal/bin"

    # Add local bin directory to PATH
    build_path "$cabal_bin" "$PATH"
    # shellcheck disable=SC2154
    export PATH="$build_path"

    unset cabal_bin
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
