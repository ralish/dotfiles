if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

try {
    if (!$DotFilesFastLoad) {
        Test-ModuleAvailable -Name PSWinVitals
    }
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping PSWinVitals settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading PSWinVitals settings ...')

# Invoke-VitalMaintenance: Exclude Silverlight updates
$PSDefaultParameterValues['Invoke-VitalMaintenance:WUTitleExclude'] = 'Silverlight'
