# posh-git
# https://github.com/dahlbyk/posh-git

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'posh-git'
    Module          = 'posh-git'
    ModuleOperation = 'Import'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup `posh-git` configuration
Function Initialize-PoshGit {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Verify module version is at least v1.0.0
    $CurrentVersion = (Get-Module -Name 'posh-git' -Verbose:$false).Version
    $RequiredVersion = [Version]::new('1.0.0')
    if ($CurrentVersion -lt $RequiredVersion) {
        Write-DotFilesMessage -Type 'Warning' -Message "Expected at least v${RequiredVersion} but found v${CurrentVersion}."
    }

    # Abbreviate home directory path with a tilde
    $Global:GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true

    # Prefix prompt with username and hostname
    $Global:GitPromptSettings.DefaultPromptPrefix.Text = "${Env:USERNAME}@${Env:COMPUTERNAME}"
}

Initialize-PoshGit

Remove-Item -LiteralPath 'Function:\Initialize-PoshGit'
Complete-DotFilesSection
