# posh-git
# https://github.com/dahlbyk/posh-git

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'posh-git'
    Module          = 'posh-git'
    ModuleOperation = 'Import'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Check for at least v1.0.0
$CurrentVersion = (Get-Module -Name 'posh-git' -Verbose:$false).Version
$RequiredVersion = [Version]::new('1.0.0')
if ($CurrentVersion -ge $RequiredVersion) {
    # Abbreviate home directory path with a tilde
    $GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true

    # Prefix prompt with username and hostname
    $GitPromptSettings.DefaultPromptPrefix.Text = "${Env:USERNAME}@${Env:COMPUTERNAME}"
} else {
    Write-DotFilesMessage -Type 'Warning' -Message "Expected at least v${RequiredVersion} but found v${CurrentVersion}."
}

Remove-Variable -Name 'CurrentVersion', 'RequiredVersion'
Complete-DotFilesSection
