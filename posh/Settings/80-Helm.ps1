# Helm
# https://helm.sh/
# https://github.com/helm/helm

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'Helm'
    Command = 'helm'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup Helm configuration
Function Initialize-Helm {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # (Re)build the native completions script
    $CompletionsFile = Join-Path -Path $Global:PoshCompletionsPath -ChildPath 'helm.ps1'
    if ($Env:DOTFILES_REBUILD_COMPLETIONS -or !(Test-Path -LiteralPath $CompletionsFile -PathType 'Leaf')) {
        Write-DotFilesMessage -Type 'Verbose' -Message 'Building native completions script ...'
        & helm completion powershell | Out-File -FilePath $CompletionsFile -Encoding 'utf8'
    }

    Write-DotFilesMessage -Type 'Verbose' -Message 'Registering native argument completer ...'
    Get-Content -LiteralPath $CompletionsFile | Out-String | Invoke-Expression # DevSkim: ignore DS104456
}

Initialize-Helm

Remove-Item -LiteralPath 'Function:\Initialize-Helm'
Complete-DotFilesSection
