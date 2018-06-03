# Recursively find files without a trailing newline
# Via: https://unix.stackexchange.com/a/315972

function find-files-no-trailing-newline() {
    zmodload zsh/system

    for file (**/*(D.L+0)) {
        {
            sysseek -w end -2
            sysread
            [[ $REPLY = $'\n' || $REPLY = $'\n\n' ]] && print -r -- $file
        } < $file
    }

    return 0
}

# vim: syntax=zsh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
