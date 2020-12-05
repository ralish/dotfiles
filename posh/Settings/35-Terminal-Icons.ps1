try {
    Import-Module -Name Terminal-Icons -ErrorAction Stop -Verbose:$false
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping Terminal-Icons settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading Terminal-Icons settings ...')
