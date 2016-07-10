#!/bin/sh

# lesspipe configuration

if command -v lesspipe > /dev/null; then
    # Make use of lesspipe for handling non-text input
    eval "$(SHELL=/bin/sh lesspipe)"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
