#!/bin/sh

# Linux shell configuration

# Use stderred if it's available
USE_STDERRED='true'

# Load stderred if requested & it's present
stderred_path='/usr/local/lib/libstderred.so'
if [ -n "$USE_STDERRED" ]; then
    if [ -f "$stderred_path" ]; then
        export LD_PRELOAD="$stderred_path${LD_PRELOAD:+:$LD_PRELOAD}"
    fi
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
