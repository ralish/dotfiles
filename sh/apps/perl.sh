# shellcheck shell=sh

# Perl configuration
if command -v perl > /dev/null; then
    perl5_dir="${HOME}/perl5"

    # Setup local Perl environment
    if [ -d "$perl5_dir" ]; then
        build_path "${perl5_dir}/bin" "$PATH"
        # shellcheck disable=SC2154
        export PATH="$build_path"

        build_path "${perl5_dir}/lib/perl5" "$PERL5LIB"
        export PERL5LIB="$build_path"

        build_path "$perl5_dir" "$PERL_LOCAL_LIB_ROOT"
        export PERL_LOCAL_LIB_ROOT="$build_path"

        export PERL_MB_OPT="--install_base \"${perl5_dir}\""
        export PERL_MM_OPT="INSTALL_BASE=${perl5_dir}"
    fi

    unset perl5_dir
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
