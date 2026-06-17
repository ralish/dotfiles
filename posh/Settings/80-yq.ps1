# yq
# https://github.com/mikefarah/yq

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'yq'
    Command = 'yq'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# (Re)build the native completions script
$CompletionsFile = Join-Path -Path $PoShCompletionsPath -ChildPath 'yq.ps1'
if ($Env:DOTFILES_REBUILD_COMPLETIONS -or !(Test-Path -LiteralPath $CompletionsFile -PathType 'Leaf')) {
    Write-DotFilesMessage -Type 'Verbose' -Message 'Building native completions script ...'
    & yq shell-completion powershell | Out-File -FilePath $CompletionsFile -Encoding 'utf8'
}

Write-DotFilesMessage -Type 'Verbose' -Message 'Registering native argument completer ...'
Get-Content -LiteralPath $CompletionsFile | Out-String | Invoke-Expression # DevSkim: ignore DS104456

Remove-Variable -Name 'CompletionsFile'
Complete-DotFilesSection
