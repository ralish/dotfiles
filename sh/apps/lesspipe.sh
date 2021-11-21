# shellcheck shell=sh

# lesspipe configuration
if command -v lesspipe > /dev/null; then
    # Setup lesspipe for handling non-text input
    # shellcheck disable=SC2312
    eval "$(lesspipe)"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
