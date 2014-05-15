# Cygwin shell configuration

# Because I never remember the '-s' parameter
alias ssh-agent-cyg='eval $(ssh-agent -s)'

# Add alias for Sublime Text
SublRegPath='/proc/registry/HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows/CurrentVersion/Uninstall/Sublime Text 2_is1/InstallLocation'
SublBinName='sublime_text.exe'
if [ -f "$SublRegPath" ]; then
    SublDirPath=$(cat "$SublRegPath" | sed 's/^\([A-Z]\):/\/cygdrive\/\1/' | sed 's/\\/\//g')
    alias subl="\"$SublDirPath$SublBinName\""
fi

# vim: syntax=sh ts=4 sw=4 sts=4 et sr
