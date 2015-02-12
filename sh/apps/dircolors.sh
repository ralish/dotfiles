# dircolors configuration

if command -v dircolors > /dev/null; then
    # Use our custom dircolors configuration
    if [ -r "$HOME/.dircolors" ]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    # Otherwise just use the default dircolors
    else
        eval "$(dircolors -b)"
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
