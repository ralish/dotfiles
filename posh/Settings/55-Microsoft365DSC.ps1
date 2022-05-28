$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Microsoft 365 DSC'
    Platform        = 'Windows'
    Module          = @('Microsoft365DSC')
    ForceTestModule = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Opt-out of telemetry
$TelemetryStatus = Get-EnvironmentVariable -Name M365DSCTelemetryEnabled -Scope Machine
if ($TelemetryStatus -ne 'False') {
    Write-Warning -Message 'Telemetry is enabled for the Microsoft365DSC module.'
}

Complete-DotFilesSection
