#!/usr/bin/env csh

# C shell
# https://man.netbsd.org/csh.1
#
# Last reviewed release: v20240808
# Upstream source: https://cvsweb.openbsd.org/src/bin/csh/
# Default file path: ~/.cshrc
#
# Configuration is performed entirely through shell variables, which has the
# useful property of providing simple backwards compatibility even with very
# old releases. Where a csh release does not support a feature, the variable
# will effectively be a no-op.
#
# csh is not compatible with the Bourne shell (`sh`), so our common shell
# configuration (`sh/common.sh`) cannot be used.

# If we're not running interactively then bail out
if ( $?prompt == 0 ) exit

##################################################
###                 Completion                 ###
##################################################

# Enable filename completion
set filec

# List of filename suffixes excluded from filename completion
#set fignore = ( )

##################################################
###             Directory handling             ###
##################################################

# List of alternate directories searched by `chdir`
#set cdpath = ( )

##################################################
###            Execution & parsing             ###
##################################################

# Enable restrictions on output redirection
#
# If set, `>` redirection must be to a file that does not exist or a character
# special file (e.g. `/dev/null`). `>>` redirection must be to a file which
# already exists.
#set noclobber

##################################################
###                 Expansion                  ###
##################################################

# Inhibit filename expansion
#set noglob

# Allow filename expansions which do not match any files
#set nonomatch

##################################################
###                  History                   ###
##################################################

# Maximum size of the history list
set history = 1000

# Characters used for history substitution
#
# 1st character: History substitution
# 2nd character: Quick substitution
#
# If unset, the default is `!^`.
#set histchars =

# Path to save the history
set histfile = ~/.csh_history

# Save history entries to the history file on shell exit
#
# A numeric value can optionally be provided to control the maximum number of
# history entries to save. If unspecified, the value of `history` is used.
set savehist

##################################################
###                Shell input                 ###
##################################################

# Ignore EOF from input devices which are terminals
#set ignoreeof

##################################################
###                Shell output                ###
##################################################

# Echo each command before executing (`-x` option)
#set echo

# Inhibit use of the terminal bell to signal errors or ambiguous completion
set nobeep

# Notify on job completions asynchronously
#set notify

# Echo the words of each command after history substitution (`-v` option)
#set verbose

##################################################
###               Miscellaneous                ###
##################################################

# List of files which are periodically checked for mail
#
# If the first word is numeric it specifies the check interval (secs).
#set mail = ( )

# Duration of CPU time used by a command which triggers timing info (secs)
#set time =

##################################################
###            Prompt customisation            ###
##################################################

# Retrieve the short hostname to use in the prompt
set prompt_hostname = `hostname -s`

# Format string of the prompt for command input
#
# The default is `% ` for users and `# ` for the superuser.
set prompt = "${USER:q}@${prompt_hostname:q}> "

# Format string of the prompt for incomplete multi-line commands
#
# The default is `? `.
#set prompt2 =

# vim: syntax=csh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
