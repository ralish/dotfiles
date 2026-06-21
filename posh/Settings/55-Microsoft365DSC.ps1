# Microsoft365DSC
# https://microsoft365dsc.com/
# https://github.com/Microsoft365DSC/Microsoft365DSC

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Microsoft365DSC'
    Module          = 'Microsoft365DSC'
    Platform        = 'Windows'
    ForceTestModule = $true
    Async           = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Check `Microsoft365DSC` telemetry is disabled system-wide
Function Test-Microsoft365DSCTelemetry {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Check if telemetry is disabled
    $TelemetryStatus = Get-EnvironmentVariable -Name 'M365DSCTelemetryEnabled' -Scope 'Machine'
    if ($TelemetryStatus -ne 'False') {
        Write-DotFilesMessage -Type 'Warning' -Message 'Telemetry is enabled for the Microsoft365DSC module.'
    }
}

Test-Microsoft365DSCTelemetry

Remove-Item -LiteralPath 'Function:\Test-Microsoft365DSCTelemetry'
Complete-DotFilesSection
