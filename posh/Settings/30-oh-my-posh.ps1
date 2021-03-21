if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

try {
    Import-Module -Name oh-my-posh -ErrorAction Stop -Verbose:$false
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping oh-my-posh settings as module not found.')
    return
}

$CurrentVersion = (Get-Module -Name oh-my-posh).Version
$RequiredVersion = [Version]::new('2.0.0')
if ($CurrentVersion -ge $RequiredVersion) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading oh-my-posh settings ...')

    # Set console theme
    if ($CurrentVersion.Major -ge 3) {
        Set-PoshPrompt -Theme slim -Verbose:$false
    } else {
        Set-Theme -name Agnoster -Verbose:$false
    }
} else {
    Write-Warning -Message (Get-DotFilesMessage -Message ('Expecting at least oh-my-posh {0} but you have {1}.' -f $RequiredVersion, $CurrentVersion))
}

Remove-Variable -Name 'CurrentVersion', 'RequiredVersion'
