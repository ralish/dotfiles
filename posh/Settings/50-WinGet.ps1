# WinGet
# https://learn.microsoft.com/en-au/windows/package-manager/winget/
# https://github.com/microsoft/winget-cli

$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'WinGet'
    Platform = 'Windows'
    Command  = 'winget'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Tab completion (winget)
# https://learn.microsoft.com/en-au/windows/package-manager/winget/tab-completion
Write-Verbose -Message (Get-DotFilesMessage 'Registering dynamic argument completer ...')
Register-ArgumentCompleter -Native -CommandName 'winget' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)

    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [Text.UTF8Encoding]::new()
    $Word = $wordToComplete.Replace('"', '""')
    $AST = $commandAst.ToString().Replace('"', '""')
    & winget complete --word=$Word --commandline $AST --position $cursorPosition | ForEach-Object {
        [Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
    }
}

Complete-DotFilesSection
