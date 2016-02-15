# less configuration

if command -v less > /dev/null; then
    # Options to pass to less
    export LESS='-i -R'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
