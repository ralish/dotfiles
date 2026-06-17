# AzCopy
# https://learn.microsoft.com/en-au/azure/storage/common/storage-use-azcopy-v10
# https://github.com/Azure/azure-storage-azcopy

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'AzCopy'
    Command = 'azcopy'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Disable logging to the system log
$Env:AZCOPY_DISABLE_SYSLOG = 'true'

# (Re)build the native completions script
$CompletionsFile = Join-Path -Path $PoShCompletionsPath -ChildPath 'azcopy.ps1'
if ($Env:DOTFILES_REBUILD_COMPLETIONS -or !(Test-Path -LiteralPath $CompletionsFile -PathType 'Leaf')) {
    Write-Verbose -Message (Get-DotFilesMessage 'Building native completions script ...')
    & azcopy completion powershell | Out-File -FilePath $CompletionsFile -Encoding 'utf8'
}

Write-Verbose -Message (Get-DotFilesMessage 'Registering native argument completer ...')
Get-Content -LiteralPath $CompletionsFile | Out-String | Invoke-Expression # DevSkim: ignore DS104456

Remove-Variable -Name 'CompletionsFile'
Complete-DotFilesSection
