$null = Start-DotFilesSection -Type 'Settings' -Name 'Aliases'

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
    Set-Alias -Name $Alias -Value $Aliases[$Alias]
}

if (Test-IsWindows) {
    if (Get-Command -Name 'curl.exe' -ErrorAction 'Ignore') {
        Remove-Item -LiteralPath 'Alias:\curl' -ErrorAction 'Ignore'
    }

    if (Get-Command -Name 'diff.exe' -ErrorAction 'Ignore') {
        Remove-Item -LiteralPath 'Alias:\diff' -Force -ErrorAction 'Ignore'
    }

    if (Get-Command -Name 'sc.exe' -ErrorAction 'Ignore') {
        Remove-Item -LiteralPath 'Alias:\sc' -Force -ErrorAction 'Ignore'
    }

    if (Get-Command -Name 'wget.exe' -ErrorAction 'Ignore') {
        Remove-Item -LiteralPath 'Alias:\wget' -ErrorAction 'Ignore'
    }
}

Remove-Variable -Name 'Aliases'
Complete-DotFilesSection
