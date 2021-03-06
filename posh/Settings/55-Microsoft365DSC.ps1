if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

try {
    # Don't support our fast load approach as otherwise we will warn on
    # the telemetry opt-out environment variable not being set even if
    # the module is not present.
    Test-ModuleAvailable -Name Microsoft365DSC
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping Microsoft365DSC settings as module not found.')
    $Error.RemoveAt(0)
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading Microsoft365DSC settings ...')

# Opt-out of telemetry
$TelemetryStatus = Get-EnvironmentVariable -Name M365DSCTelemetryEnabled -Scope Machine
if ($TelemetryStatus -ne 'False') {
    Write-Warning -Message 'Telemetry is enabled for the Microsoft365DSC module.'
}
