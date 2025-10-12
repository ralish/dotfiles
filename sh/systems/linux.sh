# shellcheck shell=sh

# Linux shell configuration

# Use stderred if it's available
USE_STDERRED=1

# -----------------------------------------------------------------------------

df_log 'Loading system configuration: Linux'

# Load stderred if requested and it's present
stderred_path='/usr/local/lib/libstderred.so'
if [ -n "${USE_STDERRED-}" ]; then
    if [ -f "$stderred_path" ]; then
        build_path "$stderred_path" "$LD_PRELOAD"
        # shellcheck disable=SC2154
        export LD_PRELOAD="$build_path"
    fi
fi
unset USE_STDERRED stderred_path

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
