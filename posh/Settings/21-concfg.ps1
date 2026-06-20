# concfg
# https://github.com/lukesampson/concfg

$DotFilesSection = @{
    Type         = 'Settings'
    Name         = 'ConCfg'
    Command      = 'concfg'
    Platform     = 'Windows'
    PwshHostName = 'ConsoleHost'
    Module       = 'PSReadLine'
    Environment  = @{ WT_SESSION = $false }
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Set `PSReadLine` colours based on theme
& concfg tokencolor -n enable

Complete-DotFilesSection
