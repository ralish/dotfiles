# Enable color support of ls/*grep and make it the default
if [ -x /usr/bin/dircolors ]; then
    test -r "$HOME/.dircolors" \
        && eval "$(dircolors -b "$HOME/.dircolors")" \
        || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
