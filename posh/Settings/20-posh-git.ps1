try {
    Test-ModuleAvailable -Name posh-git
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping posh-git settings as module not found.')
    return
}

$CurrentVersion = (Get-Module -Name posh-git -ListAvailable).Version
$RequiredVersion = [Version]::new('1.0.0')
if ($CurrentVersion -ge $RequiredVersion) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading posh-git settings ...')
    Import-Module -Name posh-git

    # Abbreviate home directory path with tilde
    $GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true

    # Prefix prompt with username and hostname
    $GitPromptSettings.DefaultPromptPrefix.Text = '{0}@{1} ' -f $env:USERNAME, $env:COMPUTERNAME
} else {
    Write-Warning -Message (Get-DotFilesMessage -Message ('Expecting at least posh-git {0} but you have {1}.' -f $RequiredVersion, $CurrentVersion))
}

Remove-Variable -Name @('CurrentVersion', 'RequiredVersion')
