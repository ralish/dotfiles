if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

try {
    # Terminal-Icons runs some commands which don't respect the -Verbose
    # parameter. Suppress them via $VerbosePreference before import.
    if ($DotFilesVerbose) {
        $VerbosePreference = 'SilentlyContinue'
    }

    Import-Module -Name Terminal-Icons -ErrorAction Stop -Verbose:$false
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping Terminal-Icons settings as module not found.')
    return
} finally {
    # Restore the original $VerbosePreference setting
    if ($DotFilesVerbose) {
        $VerbosePreference = 'Continue'
    }
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading Terminal-Icons settings ...')
