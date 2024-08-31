# shellcheck shell=sh

# AWS CLI configuration
if command -v aws > /dev/null; then
    # Command completion
    # https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html
    if command -v aws_completer > /dev/null; then
        if [ -n "$ZSH_NAME" ]; then
            autoload bashcompinit && bashcompinit
            autoload -Uz compinit && compinit
        fi

        if [ -n "$BASH" ] || [ -n "$ZSH_NAME" ]; then
            # shellcheck disable=SC3044
            complete -C aws_completer aws
        fi
    fi

    # Output format
    export AWS_DEFAULT_OUTPUT='table'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
