if ($DotFilesShowScriptEntry) { Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath) }

try {
    if (!$DotFilesFastLoad) {
        Test-ModuleAvailable -Name Microsoft365DSC -Verbose:$false
    }
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping Microsoft365DSC settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading Microsoft365DSC settings ...')

# Opt-out of telemetry
$TelemetryStatus = Get-EnvironmentVariable -Name M365DSCTelemetryEnabled -Scope Machine
if ($TelemetryStatus -ne 'False') {
    Write-Warning -Message 'Telemetry is enabled for the Microsoft365DSC module.'
}
