# shellcheck shell=sh

# Cygwin shell configuration

# Cygwin package repository mirror
CYGWIN_PKGS='http://mirrors.kernel.org/sourceware/cygwin/'

# -----------------------------------------------------------------------------

# Configure package repository for apt-cyg
if command -v apt-cyg > /dev/null; then
    # shellcheck disable=SC2139
    alias apt-cyg="apt-cyg -m '$CYGWIN_PKGS'"
fi

# Fix Git prompt (__git_ps1 may not be available)
if command -v git-prompt > /dev/null; then
    # shellcheck source=/dev/null
    . "$(command -v git-prompt)"
fi

# Because I never remember the "-s" parameter
if command -v ssh-agent > /dev/null; then
    alias ssh-agent='eval $(ssh-agent -s)'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
