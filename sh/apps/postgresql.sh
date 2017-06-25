# shellcheck shell=sh

# PostgreSQL configuration
if command -v psql > /dev/null; then
    # Connect to the postgres database by default
    export PGDATABASE='postgres'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
