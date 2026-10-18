$null = Start-DotFilesSection -Type 'Settings' -Name 'Aliases'

# Configure our custom aliases
Function Initialize-Aliases {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseSingularNouns', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $Aliases = @{
        # Git
        'gita'  = 'Invoke-GitRepoCommand'
        'gits'  = 'Get-GitRepoSummary'

        # Network
        'rdn'   = 'Resolve-DnsName'

        # PowerShell
        'cop'   = 'Compare-ObjectProperties'
        'gh'    = 'Get-Help'
        'up'    = 'Update-Profile'
        'which' = 'Get-Command'
    }

    foreach ($Alias in $Aliases.Keys) {
        Set-Alias -Name $Alias -Value $Aliases[$Alias] -Scope 'Global'
    }

    if (Test-IsWindows) {
        Remove-Item -LiteralPath 'Alias:\curl' -ErrorAction 'Ignore'
        Remove-Item -LiteralPath 'Alias:\diff' -Force -ErrorAction 'Ignore'
        Remove-Item -LiteralPath 'Alias:\sc' -Force -ErrorAction 'Ignore'
        Remove-Item -LiteralPath 'Alias:\wget' -ErrorAction 'Ignore'
    }
}

try {
    Initialize-Aliases
} finally {
    Remove-Item -LiteralPath 'Function:\Initialize-Aliases'
    Complete-DotFilesSection
}
