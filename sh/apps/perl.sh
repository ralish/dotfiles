#!/bin/sh

# Perl configuration

if command -v perl > /dev/null; then
    perl5dir="$HOME/perl5"

    if [ -d "$perl5dir" ]; then
        PATH="$perl5dir/bin${PATH:+:${PATH}}"
        PERL5LIB="$perl5dir/lib/perl5${PERL5LIB:+:${PERL5LIB}}"
        PERL_LOCAL_LIB_ROOT="$perl5dir${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
        PERL_MB_OPT="--install_base \"$perl5dir\""
        PERL_MM_OPT="INSTALL_BASE=$perl5dir"
        export PATH PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MB_OPT PERL_MM_OPT
    fi

    unset perl5dir
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
