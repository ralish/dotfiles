# shellcheck shell=sh

# Homebrew configuration
brew_path_home="${HOME}/.linuxbrew/bin/brew"
brew_path_linux='/home/linuxbrew/.linuxbrew/bin/brew'

# Locate installation
if [ -f "$brew_path_home" ] && [ -x "$brew_path_home" ]; then
    brew_path="$brew_path_home"
elif [ -f "$brew_path_linux" ] && [ -x "$brew_path_linux" ]; then
    brew_path="$brew_path_linux"
elif command -v brew > /dev/null; then
    brew_path="$(command -v brew)"
fi

if df_app_load 'Homebrew [brew]' "[ -n \"$brew_path\" ]"; then
    # Opt-out of analytics
    export HOMEBREW_NO_ANALYTICS=1

    # GitHub Personal Access Token for increased API rate limit
    if [ -n "$DOTFILES_GITHUB_API_TOKEN" ]; then
        export HOMEBREW_GITHUB_API_TOKEN="$DOTFILES_GITHUB_API_TOKEN"
    fi

    # Setup environment variables
    # shellcheck disable=SC2312
    eval "$("$brew_path" shellenv)"

    # brew Shell Completion
    # https://docs.brew.sh/Shell-Completion
    if [ -n "$BASH" ]; then
        # shellcheck disable=SC2154
        if [ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]; then
            # shellcheck source=/dev/null
            . "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
        else
            for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
                # shellcheck source=/dev/null
                [ -r "$COMPLETION" ] && . "$COMPLETION"
            done
        fi
    elif [ -n "$ZSH_NAME" ]; then
        FPATH="${HOMEBREW_PREFIX}/share/zsh/site-functions:${FPATH}"
        autoload -Uz compinit
        compinit
    fi
fi

unset brew_path brew_path_home brew_path_linux

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
