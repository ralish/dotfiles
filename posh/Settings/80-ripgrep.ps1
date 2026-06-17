# ripgrep
# https://ripgrep.org/
# https://github.com/BurntSushi/ripgrep

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'ripgrep'
    Command = 'rg'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Configuration file path
$Env:RIPGREP_CONFIG_PATH = Join-Path -Path $HOME -ChildPath '.ripgreprc'

# (Re)build the native completions script
$CompletionsFile = Join-Path -Path $PoShCompletionsPath -ChildPath 'rg.ps1'
if ($Env:DOTFILES_REBUILD_COMPLETIONS -or !(Test-Path -LiteralPath $CompletionsFile -PathType 'Leaf')) {
    Write-DotFilesMessage -Type 'Verbose' -Message 'Building native completions script ...'
    & rg --generate=complete-powershell | Out-File -FilePath $CompletionsFile -Encoding 'utf8'
}

Write-DotFilesMessage -Type 'Verbose' -Message 'Registering native argument completer ...'
Get-Content -LiteralPath $CompletionsFile | Out-String | Invoke-Expression # DevSkim: ignore DS104456

Remove-Variable -Name 'CompletionsFile'
Complete-DotFilesSection
