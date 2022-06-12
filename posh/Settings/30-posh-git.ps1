$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'posh-git'
    Module          = @('posh-git')
    ModuleOperation = 'Import'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

$CurrentVersion = (Get-Module -Name 'posh-git').Version
$RequiredVersion = [Version]::new('1.0.0')
if ($CurrentVersion -ge $RequiredVersion) {
    # Abbreviate home directory path with tilde
    $GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true

    # Prefix prompt with username and hostname
    $GitPromptSettings.DefaultPromptPrefix.Text = '{0}@{1} ' -f $env:USERNAME, $env:COMPUTERNAME
} else {
    Write-Warning -Message (Get-DotFilesMessage -Message ('Expecting at least posh-git {0} but you have {1}.' -f $RequiredVersion, $CurrentVersion))
}

Remove-Variable -Name 'CurrentVersion', 'RequiredVersion'
Complete-DotFilesSection
