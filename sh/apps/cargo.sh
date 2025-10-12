# shellcheck shell=sh

# Cargo configuration
cargo_path="${CARGO_HOME:-${HOME}/.cargo}"
cargo_bin="${cargo_path}/bin"

if df_app_load 'cargo' "[ -d \"$cargo_bin\" ]"; then
    # Add local bin directory to PATH
    build_path "$cargo_bin" "$PATH"
    # shellcheck disable=SC2154
    export PATH="$build_path"
fi

unset cargo_bin cargo_path

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
