if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Get-Command -Name docker -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping Docker settings as unable to locate docker.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading Docker settings ...')

try {
    Import-Module -Name DockerCompletion -ErrorAction Stop -Verbose:$false
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Docker command completion unavailable as DockerCompletion module not found.')
}
