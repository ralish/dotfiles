$DotFilesSection = @{
    Type         = 'Settings'
    Name         = 'ConCfg'
    Platform     = 'Windows'
    PwshHostName = @('ConsoleHost')
    Command      = @('concfg')
    Environment  = @{ WT_SESSION = $false }
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Set PSReadLine colours based on theme
& concfg tokencolor -n enable

Complete-DotFilesSection
