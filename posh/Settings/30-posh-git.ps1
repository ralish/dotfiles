if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

try {
    # posh-git runs some commands which don't respect the -Verbose
    # parameter. Suppress them via $VerbosePreference before import.
    if ($DotFilesVerbose) {
        $VerbosePreference = 'SilentlyContinue'
    }

    Import-Module -Name posh-git -ErrorAction Stop -Verbose:$false
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping posh-git settings as module not found.')
    return
} finally {
    # Restore the original $VerbosePreference setting
    if ($DotFilesVerbose) {
        $VerbosePreference = 'Continue'
    }
}

$CurrentVersion = (Get-Module -Name posh-git).Version
$RequiredVersion = [Version]::new('1.0.0')
if ($CurrentVersion -ge $RequiredVersion) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading posh-git settings ...')

    # Abbreviate home directory path with tilde
    $GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true

    # Prefix prompt with username and hostname
    $GitPromptSettings.DefaultPromptPrefix.Text = '{0}@{1} ' -f $env:USERNAME, $env:COMPUTERNAME
} else {
    Write-Warning -Message (Get-DotFilesMessage -Message ('Expecting at least posh-git {0} but you have {1}.' -f $RequiredVersion, $CurrentVersion))
}

Remove-Variable -Name 'CurrentVersion', 'RequiredVersion'
