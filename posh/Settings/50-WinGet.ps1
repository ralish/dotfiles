# WinGet
# https://learn.microsoft.com/en-au/windows/package-manager/winget/
# https://github.com/microsoft/winget-cli

$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'WinGet'
    Command  = 'winget'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Tab completion (winget)
# https://learn.microsoft.com/en-au/windows/package-manager/winget/tab-completion
Write-DotFilesMessage -Type 'Verbose' -Message 'Registering dynamic argument completer ...'
Register-ArgumentCompleter -Native -CommandName 'winget' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)

    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [Text.UTF8Encoding]::new()
    $Word = $wordToComplete.Replace('"', '""')
    $Ast = $commandAst.ToString().Replace('"', '""')
    & winget complete --word=$Word --commandline $Ast --position $cursorPosition | ForEach-Object {
        [Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
    }
}

Complete-DotFilesSection
