# PowerShellGet
# https://learn.microsoft.com/en-au/powershell/module/powershellget/
# https://github.com/powershell/powershellget

$DotFilesSection = @{
    Type   = 'Settings'
    Name   = 'PowerShellGet'
    Module = 'PowerShellGet'
    Async  = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup `PowerShellGet` configuration
Function Initialize-PowerShellGet {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Development files to exclude when publishing
    $ExcludePaths = @(
        '.git/**'
        '.vscode/**'
        '.editorconfig'
        '.markdownlint.json'
        'PSScriptAnalyzerSettings.psd1'
    )

    # `Install-Module`: Default to `CurrentUser` scope
    $PSDefaultParameterValues['Install-Module:Scope'] = 'CurrentUser'

    # `Publish-Module`: Exclude development files
    $PSDefaultParameterValues['Publish-Module:Exclude'] = $ExcludePaths

    # Retrieve latest installed module version
    $PowerShellGet = Test-ModuleAvailable -Name 'PowerShellGet' -PassThru

    # v3 includes major changes to commands and parameters
    if ($PowerShellGet.Version.Major -ge 3) {
        # `Install-PSResource`: Default to `CurrentUser` scope
        $PSDefaultParameterValues['Install-PSResource:Scope'] = 'CurrentUser'

        # `Publish-Module`: Exclude development files
        $PSDefaultParameterValues['Publish-PSResource:Exclude'] = $ExcludePaths
    }
}

Initialize-PowerShellGet

Remove-Item -LiteralPath 'Function:\Initialize-PowerShellGet'
Complete-DotFilesSection
