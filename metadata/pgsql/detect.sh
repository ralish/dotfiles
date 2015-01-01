#!/usr/bin/env bash

if ! command -v psql > /dev/null; then
    exit 1
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
