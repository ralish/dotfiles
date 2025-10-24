# shellcheck shell=sh

df_log 'Setting preferred editor ...'

if [ -z "$PREFERRED_EDITORS" ]; then
    df_log 'Skipping setting editor as PREFERRED_EDITORS is empty.'
    return
fi

# Attempt to set one of our preferred editors
editor_found=false
for editor in $PREFERRED_EDITORS; do
    editor_path="$(command -v "$editor")"
    if [ -n "$editor_path" ]; then
        export EDITOR="$editor_path"
        export VISUAL="$editor_path"
        editor_found=true
        df_log "Set EDITOR and VISUAL to: $EDITOR"
        break
    fi
done
unset editor editor_path

if [ "$editor_found" = 'false' ]; then
    echo '[dotfiles] No preferred editors were found.'
fi
unset editor_found

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
