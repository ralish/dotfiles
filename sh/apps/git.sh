# shellcheck shell=sh

# git configuration
if command -v git > /dev/null; then
    # Handy aliases to switch to the root of the repository
    alias git-repo-root='cd "$(git rev-parse --show-toplevel)"'
    alias grr='git-repo-root'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
