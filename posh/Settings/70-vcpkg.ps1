$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'vcpkg'
    Command = @('vcpkg')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Disable telemetry
$env:VCPKG_DISABLE_METRICS = 'true'

Complete-DotFilesSection
