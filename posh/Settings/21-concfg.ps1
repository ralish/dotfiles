if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

if ($Host.Name -ne 'ConsoleHost') {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ConCfg settings as host is not ConsoleHost.')
    return
}

if ($env:WT_SESSION) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ConCfg settings as running under Windows Terminal.')
    return
}

if (!(Get-Command -Name concfg -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ConCfg settings as unable to locate concfg.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading ConCfg settings ...')

# Suppress ConCfg verbose output on loading
if ($DotFilesVerbose) {
    $VerbosePreference = 'SilentlyContinue'
}

# Set PSReadLine colours based on theme
& concfg tokencolor -n enable

# Restore the original $VerbosePreference setting
if ($DotFilesVerbose) {
    $VerbosePreference = 'Continue'
}
