# shellcheck shell=sh

# aws configuration
if command -v aws > /dev/null; then
    # Command completion
    # https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html
    if command -v aws_completer > /dev/null; then
        # shellcheck disable=SC2154
        if [ -n "$ZSH_NAME" ]; then
            autoload bashcompinit && bashcompinit
        fi

        if [ -n "$BASH" ] || [ -n "$ZSH_NAME" ]; then
            # shellcheck disable=SC2039
            complete -C aws_completer aws
        fi
    fi

    unset dotnet_bin
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
