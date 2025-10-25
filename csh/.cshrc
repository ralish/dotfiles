#!/usr/bin/env csh

# C shell
#
# Last reviewed release: v20230828
# Default file path: ~/.cshrc
#
# csh is *not* compatible with the Bourne shell (sh) so we cannot use our
# common shell setup configuration (sh/common.sh).

# If we're not running interactively then bail out
if ($?prompt == 0) exit

##################################################
###              Command history               ###
##################################################

# Maximum size of the history list
set history = 1024

# Characters used for history substitution
#
# 1st character: History substitution
# 2nd character: Quick substitution
set histchars = '\!^'

# Path to save the history
set histfile = ~/.csh_history

# Save history entries to the history file on shell exit
#
# A numeric value can optionally be provided to control the maximum number of
# history entries to save. If unspecified, the value of `history` is used.
set savehist

##################################################
###               Command prompt               ###
##################################################

# Format of the prompt for a command
set prompt = "${USER:q}@%m> "

# Format of the prompt for incomplete multi-line commands
set prompt2 = '? '

##################################################
###                 Completion                 ###
##################################################

# Enable filename completion
set filec

# List of filename suffixes to be excluded from filename completion
#set fignore = ( )

##################################################
###                 Expansion                  ###
##################################################

# Inhibit filename expansion
#set noglob

# Allow filename expansions which do not match any files
#set nonomatch

##################################################
###                Shell output                ###
##################################################

# Echo each command before executing (`-x` option)
#set echo

# Inhibit use of the terminal bell to signal errors or ambiguous completion
set nobeep

# Echo the words of each command after history substitution (`-v` option)
#set verbose

##################################################
###               Miscellaneous                ###
##################################################

# List of alternate directories searched by `chdir`
#set cdpath = ( )

# Ignore EOF from input devices which are terminals
#set ignoreeof

# List of files which are periodically checked for mail
#
# If the first word is numeric it specifies the check interval (seconds).
#set mail = ( )

# Enable restrictions on output redirection
#
# If set, `>` redirection must be to a file that does not exist or a character
# special file (e.g. `/dev/null`). `>>` redirections must be to a file which
# already exists.
#set noclobber

# Notify on job completions asynchronously
#set notify

# Duration of CPU time used by a command which triggers timing info (seconds)
#set time =

# vim: syntax=csh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
