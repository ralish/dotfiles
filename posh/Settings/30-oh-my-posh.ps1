if ($DotFilesShowScriptEntry) { Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath) }

try {
    Import-Module -Name oh-my-posh -ErrorAction Stop -Verbose:$false
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping oh-my-posh settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading oh-my-posh settings ...')

# Set console theme
Set-Theme -name Agnoster -Verbose:$false
