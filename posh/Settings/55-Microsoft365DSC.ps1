# Microsoft365DSC
# https://microsoft365dsc.com/
# https://github.com/Microsoft365DSC/Microsoft365DSC

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Microsoft365DSC'
    Platform        = 'Windows'
    Module          = 'Microsoft365DSC'
    ForceTestModule = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Check if telemetry is disabled
$TelemetryStatus = Get-EnvironmentVariable -Name 'M365DSCTelemetryEnabled' -Scope 'Machine'
if ($TelemetryStatus -ne 'False') {
    Write-Warning -Message 'Telemetry is enabled for the Microsoft365DSC module.'
}

Remove-Variable -Name 'TelemetryStatus'
Complete-DotFilesSection
