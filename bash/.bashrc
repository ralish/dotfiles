#!/usr/bin/env bash

# Bash Reference Manual
# https://www.gnu.org/software/bash/manual/bashref.html
#
# Last reviewed release: v5.3
# Default file path: ~/.bashrc
#
# This configuration has been written to be backwards compatible with Bash
# versions as far back as Bash 2.0. Usage of features added in subsequent
# versions are checked against the executing Bash version before enabling to
# ensure the configuration gracefully "degrades" when used with old releases.

# If we're not running interactively then bail out
case $- in
    *i*) ;;
    *) return ;;
esac

##################################################
###              Version testing               ###
##################################################

# Variables for Bash versions are only generated where there's at least one
# corresponding new feature that may need to be tested for in a given release.

# shellcheck disable=SC2034
if ((BASH_VERSINFO[0] >= 2)); then
    bash_ver_20=true
    if ((BASH_VERSINFO[0] > 2 || BASH_VERSINFO[1] >= 2)); then bash_ver_202=true; fi
    if ((BASH_VERSINFO[0] > 2 || BASH_VERSINFO[1] >= 4)); then bash_ver_204=true; fi
    if ((BASH_VERSINFO[0] > 2 || BASH_VERSINFO[1] >= 5)); then bash_ver_205=true; fi
fi

# shellcheck disable=SC2034
if ((BASH_VERSINFO[0] >= 3)); then
    bash_ver_30=true
    if ((BASH_VERSINFO[0] > 3 || BASH_VERSINFO[1] >= 1)); then bash_ver_31=true; fi
fi

# shellcheck disable=SC2034
if ((BASH_VERSINFO[0] >= 4)); then
    bash_ver_40=true
    if ((BASH_VERSINFO[0] > 4 || BASH_VERSINFO[1] >= 1)); then bash_ver_41=true; fi
    if ((BASH_VERSINFO[0] > 4 || BASH_VERSINFO[1] >= 2)); then bash_ver_42=true; fi
    if ((BASH_VERSINFO[0] > 4 || BASH_VERSINFO[1] >= 3)); then bash_ver_43=true; fi
    if ((BASH_VERSINFO[0] > 4 || BASH_VERSINFO[1] >= 4)); then bash_ver_44=true; fi
fi

# shellcheck disable=SC2034
if ((BASH_VERSINFO[0] >= 5)); then
    bash_ver_50=true
    if ((BASH_VERSINFO[0] > 5 || BASH_VERSINFO[1] >= 2)); then bash_ver_52=true; fi
    if ((BASH_VERSINFO[0] > 5 || BASH_VERSINFO[1] >= 3)); then bash_ver_53=true; fi
fi

##################################################
###            Compatibility level             ###
##################################################

# Set the shell compatibility level to match the behaviour of a previous
# version of Bash.
#
# Shell compatibility levels start from Bash 3.1 and can be provided as a
# decimal number (e.g. 3.1) or an integer (e.g. 31). Only a single shell
# compatibility level can be specified.
#if [[ -n ${bash_ver_43-} ]]; then BASH_COMPAT=; fi

# Legacy method to set the shell compatibility level to match the behaviour of
# a previous version of Bash.
#
# Usage of `shopt` to set the shell compatibility level is removed as of Bash
# 5.0. The `BASH_COMPAT` variable should be used instead unless you're using a
# version of Bash prior to 4.3.
#
# Shell compatibility levels are named in the form `compatXY`, where `X` is the
# major version and `Y` is the minor version. Compatibility levels are defined
# for Bash 3.1 through 4.4 inclusive. Only a single shell compatibility level
# can be specified.
#if [[ -n ${bash_ver_40} ]]; then shopt -s compatXY; fi

##################################################
###          Completion & correction           ###
##################################################

# Quote metacharacters in file and directory names when performing completion
if [[ -n ${bash_ver_44-} ]]; then shopt -s complete_fullquote; fi

# Replace directory names with the results of word expansion when performing
# filename completion.
if [[ -n ${bash_ver_43-} ]]; then shopt -s direxpand; fi

# Attempt spelling correction on directory names during word completion if the
# supplied directory name does not exist.
if [[ -n ${bash_ver_40-} ]]; then shopt -s dirspell; fi

# Ignore words matching the suffixes specified in the `FIGNORE` variable even
# if the ignored words are the only possible completions.
if [[ -n ${bash_ver_30-} ]]; then shopt -s force_fignore; fi

# Attempt hostname completion when a word containing `@` is being completed
#
# Only applies when Readline is being used.
if [[ -n ${bash_ver_20-} ]]; then shopt -s hostcomplete; fi

# Do not search `PATH` for possible completions when attempting completion on
# an empty line.
#
# Only applies when Readline is being used.
if [[ -n ${bash_ver_204-} ]]; then shopt -s no_empty_cmd_completion; fi

# Enable programmable completion facilities
if [[ -n ${bash_ver_204-} ]]; then shopt -s progcomp; fi

# Treat a command name that has no completions as a possible alias and attempt
# alias expansion, and if successful, attempt programmable completion on the
# resulting word from the expanded alias.
#
# Only applies when `progcomp` is enabled.
#if [[ -n ${bash_ver_50-} ]]; then shopt -s progcomp_alias; fi

# List of filename suffixes excluded from filename completion (colon-separated)
#FIGNORE=

# Path to a file in the same format as `/etc/hosts` for hostname completion
#
# If empty or set to an unreadable file, `/etc/hosts` will be used. If unset,
# the hostname list is cleared.
#HOSTFILE=

##################################################
###             Directory handling             ###
##################################################

# Treat a command name which matches the name of a directory as if it were an
# argument to the `cd` builtin.
#
# Only applies to interactive shells.
#if [[ -n ${bash_ver_40-} ]]; then shopt -s autocd; fi

# Assume an argument to the `cd` builtin which does not match a directory is
# the name of a variable whose value is the directory to change to.
#shopt -s cdable_vars

# Attempt correction of minor spelling errors in directory path components when
# using the `cd` builtin.
#
# Only applies to interactive shells.
shopt -s cdspell

# List of directories used as a search path for `cd` (colon-separated)
#CDPATH=

##################################################
###            Execution & parsing             ###
##################################################

# Suppress multiple evaluation of associative and indexed array subscripts
#
# This behaviour applies:
# - During arithmetic expression evaluation
# - While executing builtins that can perform variable assignments
# - While executing builtins that perform array dereferencing
#if [[ -n ${bash_ver_53-} ]]; then
#    shopt -s array_expand_once
#elif [[ -n ${bash_ver_50-} ]]; then
#    shopt -s assoc_expand_once
#fi

# Convert filenames added to the `BASH_SOURCE` array variable to full pathnames
#if [[ -n ${bash_ver_53-} ]]; then shopt -s bash_source_fullpath; fi

# Do not exit if a file specified to the `exec` builtin cannot be executed
#
# Only applies to non-interactive shells.
#shopt -s execfail

# Inherit the value of the `errexit` option with command substitution instead
# of unsetting it in the subshell environment.
#
# Enabled when POSIX mode is enabled.
#if [[ -n ${bash_ver_44-} ]]; then shopt -s inherit_errexit; fi

# Ignore words beginning with `#` and all remaining characters on the line
#
# Only applies to interactive shells.
shopt -s interactive_comments

# Run the last command of a pipeline not executed in the background in the
# current shell environment.
#
# Only applies when job control is not active.
#if [[ -n ${bash_ver_42-} ]]; then shopt -s lastpipe; fi

# Local variables which have not had a value assigned inherit the value and
# attributes of variables with the same name which exist at a previous scope.
#
# This behaviour does not apply for the `nameref` attribute.
#if [[ -n ${bash_ver_50-} ]]; then shopt -s localvar_inherit; fi

# Calling `unset` on local variables defined in previous function scopes marks
# them so any subsequent lookups find them unset until the function returns.
#if [[ -n ${bash_ver_50-} ]]; then shopt -s localvar_unset; fi

# Enclose the translated results of `$"..."` quoting in single quotes intead of
# double quotes.
#if [[ -n ${bash_ver_52-} ]]; then shopt -s noexpand_translation; fi

# Use the value of `PATH` to locate the file supplied as an argument to the
# `source` (`.`) builtin when the `-p` option is not provided.
#
# Set by default, but we unset it as the behaviour it enables is a bit scary.
shopt -u sourcepath

# Automatically close file descriptors assigned using the `{varname}`
# redirection syntax instead of leaving them open on command completion.
#if [[ -n ${bash_ver_52-} ]]; then shopt -s varredir_close; fi

# Expand backslash escape sequences used with the `echo` builtin by default
#if [[ -n ${bash_ver_204-} ]]; then shopt -s xpg_echo; fi

# List of directories which the `enable` builtin will search for dynamically
# loadable builtins (colon-separated).
#if [[ -n ${bash_ver_44-} ]]; then BASH_LOADABLES_PATH=; fi

# Number of exited child status values to remember
#
# Cannot be set below a POSIX-mandated minimum, for which the specific minimum
# is dependent on the system. The maximum value is 8192.
#if [[ -n ${bash_ver_43-} ]]; then CHILD_MAX=; fi

# List of patterns to exclude matching files in `PATH` search (colon-separated)
#
# Files with a full pathname which match a pattern are not considered to be
# executable files for the purpose of completion and command execution via a
# `PATH` lookup.
#
# This option does not affect the behaviour of the `[`, `test`, and `[[`
# commands. Full pathnames in the command hash table are not checked against
# patterns. The pattern matching honours the `extglob` shell option.
#if [[ -n ${bash_ver_44-} ]]; then EXECIGNORE=; fi

# Maximum function nesting level
#
# Function invocations exceeding the nesting level cause the command to abort.
#if [[ -n ${bash_ver_42-} ]]; then FUNCNEST=; fi

# List of characters that denote separate fields
#
# Used to perform word splitting during expansion and by the `read` builtin.
# The default is `$' \t\n'`, which will split on spaces, tabs, and newlines.
#IFS=

# Enable POSIX mode
#
# If set while the shell is running, equivalent to the `set -o posix` command.
# If in the environment while starting, equivalent to the `--posix` option.
#POSIXLY_CORRECT=

# Default timeout used for various functionality (secs)
#
# If greater than zero, the specified timeout is applied to:
# - `read` builtin
#   Used as the default timeout.
# - `select` command
#   Used as the default timeout for input when from the terminal.
# - Inactivity timeout (interactive shells only)
#   Time to wait for a complete line of input before terminating.
#
# If unset, no timeout is applied.
#TMOUT=

# Path to the directory to be used for temporary file storage
#if [[ -n ${bash_ver_205-} ]]; then TMPDIR=; fi

##################################################
###          Expansion & substitution          ###
##################################################

# Include filenames beginning with `.` in the results of filename expansion
shopt -s dotglob

# Enable alias expansion
shopt -s expand_aliases

# Enable extended pattern matching
if [[ -n ${bash_ver_202-} ]]; then shopt -s extglob; fi

# Perform `$'string'` and `$"string"` quoting within `${parameter}` expansions
# which are enclosed in double quotes.
if [[ -n ${bash_ver_30-} ]]; then shopt -s extquote; fi

# Treat filename expansion patterns which match no files as an expansion error
#if [[ -n ${bash_ver_30-} ]]; then shopt -s failglob; fi

# Use the behaviour of the traditional C locale with range expressions used in
# pattern matching bracket expressions when performing comparisons.
if [[ -n ${bash_ver_43-} ]]; then shopt -s globasciiranges; fi

# Never match the `.` and `..` files when performing filename expansion
if [[ -n ${bash_ver_52-} ]]; then shopt -s globskipdots; fi

# Match all files and zero or more directories and subdirectories with the `**`
# glob-pattern when used in a filename expansion context.
#
# If the pattern ends with a `/` only directories and subdirectories match.
if [[ -n ${bash_ver_40-} ]]; then shopt -s globstar; fi

# Match filenames case-insensitively when performing filename expansion
#if [[ -n ${bash_ver_202-} ]]; then shopt -s nocaseglob; fi

# Perform pattern matching case-insensitively
#
# This behaviour applies:
# - When executing `case` or `[[` conditional commands
# - Performing pattern substitution word expansions
# - Filtering possible completions
#if [[ -n ${bash_ver_31-} ]]; then shopt -s nocasematch; fi

# Remove filename expansion patterns which match no files instead of expanding
# to themselves.
#shopt -s nullglob

# Expand occurrences of `&` in the replacement string of pattern substitution
# to the text matched by the pattern.
if [[ -n ${bash_ver_52-} ]]; then shopt -s patsub_replacement; fi

# List of patterns to exclude matching files during expansion (colon-separated)
#
# The pattern matching honours the `extglob` shell option.
#GLOBIGNORE=

# Sort criteria and order for filename expansion results
#
# Valid values:
# - name
#   Sort by name in lexicographic order.
# - numeric
#   Sort by name, with numeric names sorted first in numeric order, and
#   remaining names sorted in lexicographic order.
# - size
#   Sort by size.
# - mtime
#   Sort by modification time.
# - atime
#   Sort by access time.
# - ctime
#   Sort by change time.
# - blocks
#   Sort by number of blocks.
# - nosort
#   Do not sort (return files in the order they are read from the filesystem).
#
# Only a single value can be specified, which can be prefixed with a `+` to
# sort in ascending order (default), or a `-` to sort in descending order.
#
# If unset, empty, or set to an invalid value, results are sorted by name in
# ascending lexicographic order as determined by the `LC_COLLATE` variable.
if [[ -n ${bash_ver_53-} ]]; then GLOBSORT='numeric'; fi

##################################################
###                  History                   ###
##################################################

# Attempt to save multi-line commands as a single history entry
#
# Only applies when command history is enabled.
shopt -s cmdhist

# Append to instead of overwriting the history file when the shell exits
shopt -s histappend

# Provide the user the opportunity to re-edit a failed history substitution
#
# Only applies when Readline is being used.
#shopt -s histreedit

# Load the results of history substitution into the Readline editing buffer
# instead of immediately passing the results to the shell parser.
#
# Only applies when Readline is being used.
#shopt -s histverify

# Save multi-line commands to the history with embedded newlines instead of
# semicolon separators where possible.
#
# Only applies when `cmdhist` is enabled.
#shopt -s lithist

# Characters used for history expansion, substitution, and tokenisation
#
# 1st character: History expansion
# 2nd character: Quick substitution
# 3rd character: History comment (optional)
#
# If unset, the default is `!^#`. This variable is correctly lowercase.
#histchars=

# List of values specifying history list update behaviour (colon-separated)
#
# Valid values:
# - ignorespace
#   Lines which begin with a space character are not saved.
# - ignoredups
#   Lines which match the previous history entry are not saved.
# - ignoreboth
#   Equivalent to the combination of `ignorespace` and `ignoredups`.
# - erasedups (since Bash 3.0)
#   Lines which match the current line are removed before saving.
#
# Specifying multiple colon-separated values is supported from Bash 3.0.
if [[ -n ${bash_ver_30} ]]; then
    HISTCONTROL='ignoredups:ignorespace'
else
    HISTCONTROL='ignoreboth'
fi

# Path to save the history
#
# The default is `~/.bash_history`. If unset or empty, command history is not
# saved when the shell exits.
#HISTFILE=

# Maximum number of commands to retain in the history
#
# The default is 500. If set to zero, commands are not saved to the history
# list. If to set less than zero, no history limit is enforced.
HISTSIZE=100000

# Maximum number of lines to save in the history file
#
# The default is equal to `HISTSIZE`. If set to less than zero or an invalid
# value, the history file will not be truncated.
#HISTFILESIZE=

# List of patterns to exclude matching commands from history (colon-separated)
#
# Patterns are anchored at the beginning of the line and must match the entire
# line. In addition to normal shell pattern matching characters, `&` matches
# the previous history line. A backslash is used to escape an `&` character.
# The pattern matching honours the `extglob` shell option.
HISTIGNORE='bg:clear:exit:fg:history'

# Format string passed to `strftime(3)` for printing history entry timestamps
#
# If set, timestamps are saved to the history file to preserve across sessions.
if [[ -n ${bash_ver_30-} ]]; then HISTTIMEFORMAT='%Y-%m-%d %H:%M:%S '; fi

##################################################
###                Shell input                 ###
##################################################

# Editor used as the default by the `fc` builtin
#FCEDIT=

# Number of consecutive EOF characters on which to exit
#
# If empty or set to a non-numeric value, the default is 10. If unset, EOF
# indicates the end of input to the shell. Only applies to interactive shells.
#IGNOREEOF=

##################################################
###                Shell output                ###
##################################################

# Write all shell error messages in the standard GNU error message format
#if [[ -n ${bash_ver_30-} ]]; then shopt -s gnu_errfmt; fi

# Print an error message when using the `shift` builtin and the shift count
# exceeds the number of positional parameters.
#shopt -s shift_verbose

# Integer corresponding to the file descriptor to write trace output generated
# by `set -x` instead of writing to standard error (`stderr`).
#
# If unset or empty, trace output will be sent to `stderr`. Any previously set
# file descriptor is closed when unset or set to a new value. This includes the
# `stderr` file descriptor if the variable was previously set to `2`.
#if [[ -n ${bash_ver_41-} ]]; then BASH_XTRACEFD=; fi

# Display error messages generated by the `getopts` builtin
#
# The default is `1` (enabled). Any other value is treated as disabled.
#OPTERR=

# Format string of the output for the `time` builtin
#
# If unset, the default is `$'\nreal\t%3lR\nuser\t%3lU\nsys\t%3lS'`. If empty,
# no timing information will be displayed. A trailing newline is automatically
# appended when the format string is displayed.
#TIMEFORMAT=

##################################################
###               Miscellaneous                ###
##################################################

# Check commands found in the internal hash table exist before executing and
# search `PATH` if the command no longer exists.
shopt -s checkhash

# List the status of any stopped and running jobs before exiting and require a
# second consecutive exit attempt before exiting if any commands are running.
#
# Only applies to interactive shells.
if [[ -n ${bash_ver_40-} ]]; then shopt -s checkjobs; fi

# Check the window size after each non-builtin command and, if necessary,
# update the `COLUMNS` and `LINES` variables, using the file descriptor
# associated with standard error if it is a terminal.
shopt -s checkwinsize

# Enable behaviours intended for use by debuggers (consult the Bash manual)
#
# If set at shell invocation or in a shell startup file, execute the debugger
# profile before the shell starts, equivalent to the `--debugger` option.
#if [[ -n ${bash_ver_30-} ]]; then shopt -s extdebug; fi

# Send a `SIGHUP` signal to all jobs on exiting
#
# Only applies to interactive login shells.
#if [[ -n ${bash_ver_202-} ]]; then shopt -s huponexit; fi

# Display a message notifying the user that mail has been read if the file
# being checked has been accessed since the last time it was checked.
#shopt -s mailwarn

# Job control user interaction
#
# Valid values:
# - (empty)
#   Treat simple commands consisting of a single word, with no redirections, as
#   candidates for resumption of a stopped job. No ambiguity is permitted; if
#   multiple jobs match the beginning of the word, or contain the word, the
#   most recently accessed job is selected.
# - exact
#   The word must exactly match the name of a stopped job.
# - substring
#   The word must match a substring of the name of a stopped job.
# - (any other value)
#   The word must be a prefix of the name of a stopped job.
#auto_resume=

# Path to the readline initialisation file
#
# If unset, `~/.inputrc` will be used.
#INPUTRC=

# Path to a file or Maildir-format directory to periodically check for mail
#
# Only applies when `MAILPATH` is not set.
#MAIL=

# List of files which are periodically checked for mail (colon-separated)
#
# Each list entry can specify the message that is printed when new mail arrives
# by separating the filename from the message with a `?` character. The name of
# the mail file can be referenced in the message with the `$_` variable.
#MAILPATH=

# Interval on which to check for mail (secs)
#
# The default is 60. If unset or less than zero, mail checking is disabled.
if [[ -z $MAIL || -z $MAILPATH ]]; then unset MAILCHECK; fi

##################################################
###            Prompt customisation            ###
##################################################

# After expanding prompt strings, perform parameter expansion, command
# substitution, arithmetic expansion, and quote removal.
shopt -s promptvars

# Command(s) to execute before printing the primary prompt (`$PS1`)
#
# If set to an array, each element is interpreted as a command to execute. If
# not an array variable, the value is the command to execute.
PROMPT_COMMAND='history -a'

# Number of trailing directory components to retain when expanding the `\w` and
# `\W` prompt escape sequences, replacing removed characters with an ellipsis.
if [[ -n ${bash_ver_40-} ]]; then PROMPT_DIRTRIM=3; fi

# Default to a colour prompt if the terminal type appears to support it
case "$TERM" in
    xterm-color | *-256color) colour_prompt=yes ;;
    *) colour_prompt= ;;
esac

# Format string of the prompt after reading a command but before execution
#PS0=

# Configure the format string of the primary prompt
#
# The default is `\s-\v\$ `.
if [[ -n ${colour_prompt-} ]]; then
    if typeset -F __git_ps1 > /dev/null; then
        # Colour prompt with Git status
        PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\$(__git_ps1)\[\033[00m\]> "
    else
        # Colour prompt
        PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]> "
    fi
elif typeset -F __git_ps1 > /dev/null; then
    # Basic prompt with Git status
    PS1="\u@\h:\w\$(__git_ps1)> "
else
    # Basic prompt
    PS1="\u@\h:\w> "
fi
unset colour_prompt

# Set the window title to `user@host:dir` if an xterm or rxvt terminal
# shellcheck disable=SC2249
case "$TERM" in
    xterm* | rxvt*) PS1="\[\e]0;\u@\h: \w\a\]$PS1" ;;
esac

# Format string of the secondary prompt
#
# The default is `> `.
#PS2=

# Format string of the prompt used with the `select` command
#
# If unset, the default is `#? `.
#PS3=

# Format string of the prompt displayed before the command line is output when
# the `set -x` option is enabled.
#
# The first character of the expanded value is replicated multiple times, as
# necessary, to indicate multiple levels of indirection.
#
# The default is `+ `.
#PS4=

##################################################
###             Command completion             ###
##################################################

# Enable more powerful command completion if available
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        # shellcheck source=/dev/null
        source /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        # shellcheck source=/dev/null
        source /etc/bash_completion
    fi
fi

##################################################
###                Key bindings                ###
##################################################

# Immediately perform history expansion after pressing space
if [[ -n ${bash_ver_202-} ]]; then bind Space:magic-space; fi

##################################################
###             Common shell setup             ###
##################################################

# Load common shell configuration
# shellcheck source=sh/common.sh
source "$HOME/dotfiles/sh/common.sh"

##################################################
###                  Clean-up                  ###
##################################################

# Remove version testing variables
unset "${!bash_ver_@}"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
