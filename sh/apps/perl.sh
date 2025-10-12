# shellcheck shell=sh

# Perl configuration
if df_app_load 'perl' 'command -v perl > /dev/null'; then
    # Check if local::lib is available
    if ! perl -e 'eval "require local::lib"; if ($@) { exit 1 }'; then
        echo '[dotfiles] Perl found but local:lib module not available.'
        return
    fi

    # Setup the local Perl environment
    # shellcheck disable=SC2312
    eval "$(perl -Mlocal::lib)"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
