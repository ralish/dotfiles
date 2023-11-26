$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'AzCopy'
    Command = @('azcopy')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Disable logging to Event Log
$env:AZCOPY_DISABLE_SYSLOG = 'true'

Complete-DotFilesSection
