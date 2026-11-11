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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
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
    $Global:PSDefaultParameterValues['Install-Module:Scope'] = 'CurrentUser'

    # `Publish-Module`: Exclude development files
    $Global:PSDefaultParameterValues['Publish-Module:Exclude'] = $ExcludePaths

    # Retrieve latest installed module version
    $PowerShellGet = Test-ModuleAvailable -Name 'PowerShellGet' -PassThru

    # v3 includes major changes to commands and parameters
    if ($PowerShellGet.Version.Major -ge 3) {
        # `Install-PSResource`: Default to `CurrentUser` scope
        $Global:PSDefaultParameterValues['Install-PSResource:Scope'] = 'CurrentUser'

        # `Publish-Module`: Exclude development files
        $Global:PSDefaultParameterValues['Publish-PSResource:Exclude'] = $ExcludePaths
    }
}

try {
    Initialize-PowerShellGet
} finally {
    Remove-Item -LiteralPath 'Function:\Initialize-PowerShellGet'
    Complete-DotFilesSection
}
