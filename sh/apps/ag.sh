# shellcheck shell=sh

# The Silver Searcher configuration
if df_app_load 'The Silver Searcher [ag]' 'command -v ag > /dev/null'; then
    # Aliases for common operations
    alias ag-todo="ag 'fixme|hack|todo'"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
