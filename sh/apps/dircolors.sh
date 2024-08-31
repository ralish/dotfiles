# shellcheck shell=sh

# dircolors configuration
if command -v dircolors > /dev/null; then
    if [ -r "${HOME}/.dircolors" ]; then
        # Use our custom configuration
        # shellcheck disable=SC2312
        eval "$(dircolors -b "${HOME}/.dircolors")"
    else
        # Otherwise use the defaults
        # shellcheck disable=SC2312
        eval "$(dircolors -b)"
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
