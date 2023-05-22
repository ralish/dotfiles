#!/usr/bin/env bash

# Source in common metadata functions
script_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=metadata/templates/common.sh
source "$script_dir/templates/common.sh"

if ! command -v git > /dev/null; then
    exit "$DETECTION_NOT_AVAILABLE"
fi

# Install/update Git repository hooks
if [[ -d git/hooks ]]; then
    for hook_path in git/hooks/*; do
        hook_name="$(basename "$hook_path")"
        hook_link=".git/hooks/$hook_name"
        hook_target="../../git/hooks/$hook_name"

        # Avoid changing existing hooks which aren't symlinks. Don't get clever
        # and try to simplify the test; remember "-e" dereferences symlinks!
        if [[ ! -L $hook_link && ! -e $hook_link ]] || [[ -L $hook_link ]]; then
            ln -fs "$hook_target" "$hook_link"
        else
            echo "[git] Skipping existing Git hook: $hook_name"
        fi
    done
fi

# Remove any dead Git repository hooks
for hook_path in .git/hooks/*; do
    # Again, remember that "-e" is testing the dereferenced symbolic link!
    if [[ -L $hook_path && ! -e $hook_path ]]; then
        hook_info="$(basename "$hook_path")"
        if command -v readlink > /dev/null; then
            hook_target="$(readlink -f "$hook_path")"
            hook_info="$hook_info -> $hook_target"
        fi

        echo "[git] Removing dead Git hook: $hook_info"
        rm "$hook_path"
    fi
done

exit "$DETECTION_SUCCESS"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
