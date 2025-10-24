# shellcheck shell=sh

df_log 'Setting preferred locale ...'

if [ -z "$PREFERRED_LOCALES" ]; then
    df_log 'Skipping setting locale as PREFERRED_LOCALES is empty.'
    return
fi

if [ -n "$LANG" ]; then
    df_log "Skipping setting locale as LANG already set to: $LANG"
    return
fi

if ! command -v locale > /dev/null; then
    df_log "Skipping setting locale as locale command not found."
    return
fi

# Attempt to set one of our preferred locales
for locale in $PREFERRED_LOCALES; do
    if locale -a | grep "$locale" > /dev/null; then
        export LANG="$locale"
        df_log "Set locale via LANG to: $LANG"
        return
    fi
done
unset locale

echo '[dotfiles] No preferred locales were found.'

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
