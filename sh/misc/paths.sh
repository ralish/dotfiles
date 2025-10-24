# shellcheck shell=sh

df_log 'Configuring PATH ...'

# Add any ~/bin directory to our PATH
if [ -d "$HOME/bin" ]; then
    build_path "$HOME/bin" "$PATH"
    # shellcheck disable=SC2154
    export PATH="$build_path"
fi

# Add any ~/.local/bin directory to our PATH
if [ -d "$HOME/.local/bin" ]; then
    build_path "$HOME/.local/bin" "$PATH"
    export PATH="$build_path"
fi

# Add any explicit extra paths to our PATH
if [ -n "$EXTRA_PATHS" ]; then
    build_path "$EXTRA_PATHS" "$PATH"
    export PATH="$build_path"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
