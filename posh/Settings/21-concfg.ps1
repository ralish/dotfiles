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

# ConCfg runs some commands with noisy verbose output. When loading our
# profile with verbose output it tends to just be annoying. Suppress it
# by setting $VerbosePreference as the concfg command does not support
# the common PowerShell cmdlet parameters.
if ($DotFilesVerbose) {
    $VerbosePreference = 'SilentlyContinue'
}

# Set PSReadline colours based on theme
& concfg tokencolor -n enable

# Restore the original $VerbosePreference setting
if ($DotFilesVerbose) {
    $VerbosePreference = 'Continue'
}
