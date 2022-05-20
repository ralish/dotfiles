if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

if (!$DotFilesFastLoad) {
    try {
        Test-ModuleAvailable -Name PSWinVitals
    } catch {
        Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping PSWinVitals settings as module not found.')
        $Error.RemoveAt(0)
        return
    }
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading PSWinVitals settings ...')

# Get-VitalInformation: Exclude Silverlight updates
$PSDefaultParameterValues['Get-VitalInformation:WUParameters'] = @{ NotTitle = 'Silverlight' }

# Invoke-VitalMaintenance: Exclude Silverlight updates
$PSDefaultParameterValues['Invoke-VitalMaintenance:WUParameters'] = @{ NotTitle = 'Silverlight' }
