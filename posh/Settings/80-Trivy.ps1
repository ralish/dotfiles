# Trivy
# https://trivy.dev/
# https://github.com/aquasecurity/trivy

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'Trivy'
    Command = 'trivy'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup Trivy configuration
Function Initialize-Trivy {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # (Re)build the native completions script
    $CompletionsFile = Join-Path -Path $PoshCompletionsPath -ChildPath 'trivy.ps1'
    if ($Env:DOTFILES_REBUILD_COMPLETIONS -or !(Test-Path -LiteralPath $CompletionsFile -PathType 'Leaf')) {
        Write-DotFilesMessage -Type 'Verbose' -Message 'Building native completions script ...'
        & trivy completion powershell | Out-File -FilePath $CompletionsFile -Encoding 'utf8'
    }

    Write-DotFilesMessage -Type 'Verbose' -Message 'Registering native argument completer ...'
    Get-Content -LiteralPath $CompletionsFile | Out-String | Invoke-Expression # DevSkim: ignore DS104456
}

Initialize-Trivy

Remove-Item -LiteralPath 'Function:\Initialize-Trivy'
Complete-DotFilesSection
