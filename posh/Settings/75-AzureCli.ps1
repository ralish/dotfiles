$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'Azure CLI'
    Command = @('az')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Disable telemetry
$env:AZURE_CORE_COLLECT_TELEMETRY = 'false'

Complete-DotFilesSection
