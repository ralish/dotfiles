# shellcheck shell=sh

# PostgreSQL configuration
if df_app_load 'pgsql' 'command -v psql > /dev/null'; then
    # Default database to connect to
    export PGDATABASE='postgres'
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
