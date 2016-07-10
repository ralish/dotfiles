# Cabal configuration

if command -v cabal > /dev/null; then
    # Add any Cabal bin/ directory to our PATH
    if [ -d "$HOME/.cabal/bin" ]; then
        export PATH="$HOME/.cabal/bin:$PATH"
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
