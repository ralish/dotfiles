# vcpkg
# https://vcpkg.io/en/
# https://github.com/microsoft/vcpkg/

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'vcpkg'
    Command = 'vcpkg'
    Async   = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Disable telemetry
$Env:VCPKG_DISABLE_METRICS = 'true'

Complete-DotFilesSection
