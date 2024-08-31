# shellcheck shell=sh

# General configuration common to all shells we use
# Should be compatible with at least: sh, bash & zsh

# Preferred text editors ordered by priority (space-separated)
EDITOR_PRIORITY='vim vi nano pico'

# Locations to prefix to PATH (colon-separated)
EXTRA_PATHS=''

# Set to true to enable log output during loading
DOTFILES_LOG="${DOTFILES_LOG:-false}"

# -----------------------------------------------------------------------------

# Guess the dotfiles directory if $dotfiles wasn't set
if [ -z "${dotfiles-}" ]; then
    if [ -d "$HOME/dotfiles" ]; then
        dotfiles="$HOME/dotfiles"
    else
        # shellcheck disable=SC2016
        echo 'Error: $dotfiles unset and unable to guess dotfiles directory!'
        return
    fi
fi

# Helper functions
sh_dir="$dotfiles/sh"
# shellcheck source=sh/source.sh
. "$sh_dir/source.sh"

# Console Do Not Track (DNT)
# https://consoledonottrack.com/
export DO_NOT_TRACK=1

# Operating system and environment specific configuration
kernel_name="$(uname -s)"
sh_systems_dir="$sh_dir/systems"
if [ "${kernel_name#*CYGWIN_NT}" != "$kernel_name" ]; then
    # shellcheck source=sh/systems/cygwin.sh
    . "$sh_systems_dir/cygwin.sh"
elif [ "${kernel_name#*Darwin}" != "$kernel_name" ]; then
    # shellcheck source=sh/systems/macos.sh
    . "$sh_systems_dir/macos.sh"
elif [ "${kernel_name#*Linux}" != "$kernel_name" ]; then
    # shellcheck source=sh/systems/linux.sh
    . "$sh_systems_dir/linux.sh"

    # shellcheck source=sh/systems/wsl.sh
    if [ -f "/proc/sys/fs/binfmt_misc/WSLInterop" ]; then
        . "$sh_systems_dir/wsl.sh"
    fi
fi
unset kernel_name sh_systems_dir

# Source in secrets that may be referenced by apps
unset dotfiles_secrets
sh_secrets_file="$sh_dir/secrets.sh"
if [ -f "$sh_secrets_file" ]; then
    dotfiles_secrets=true

    # shellcheck source=sh/secrets.sh
    . "$sh_secrets_file"

    # Make the secrets accessible as variables
    set-dotfiles-secret-vars
fi
unset sh_secrets_file

# Additional configuration for various applications
sh_apps_dir="$sh_dir/apps"
if [ -d "$sh_apps_dir" ]; then
    for sh_app in "$sh_apps_dir"/*.sh; do
        [ -e "$sh_app" ] || break
        # shellcheck source=/dev/null
        . "$sh_app"
    done
fi
unset sh_app sh_apps_dir

# Remove the secret variables (if loaded)
if [ -n "$dotfiles_secrets" ]; then
    unset-dotfiles-secret-vars
fi
unset dotfiles_secrets

# Add any ~/bin directory to our PATH
if [ -d "$HOME/bin" ]; then
    build_path "$HOME/bin" "$PATH"
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
unset EXTRA_PATHS

# Set our preferred editor
if [ -n "$EDITOR_PRIORITY" ]; then
    for editor in $EDITOR_PRIORITY; do
        editor_path="$(command -v "$editor")"
        if [ -n "$editor_path" ]; then
            export EDITOR="$editor_path"
            export VISUAL="$editor_path"
            break
        fi
    done
fi
unset EDITOR_PRIORITY editor editor_path

# Include any custom aliases
sh_aliases_file="$sh_dir/aliases.sh"
if [ -f "$sh_aliases_file" ]; then
    # shellcheck source=sh/aliases.sh
    . "$sh_aliases_file"
fi
unset sh_aliases_file

# Include any custom functions
sh_functions_dir="$sh_dir/functions"
if [ -d "$sh_functions_dir" ]; then
    for sh_function in "$sh_functions_dir"/*.sh; do
        [ -e "$sh_function" ] || break
        # shellcheck source=/dev/null
        . "$sh_function"
    done
fi
unset sh_function sh_functions_dir

# Disable toggling flow control (use ixany to re-enable)
stty -ixon

# Clean-up
unset build_path sh_dir

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
