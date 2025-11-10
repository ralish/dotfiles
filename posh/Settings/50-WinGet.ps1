$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'WinGet'
    Platform = 'Windows'
    Command  = @('winget')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Tab completion (winget)
# https://learn.microsoft.com/en-au/windows/package-manager/winget/tab-completion
Register-ArgumentCompleter -Native -CommandName 'winget' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [Text.UTF8Encoding]::new()
    $Local:Word = $wordToComplete.Replace('"', '""')
    $Local:AST = $commandAst.ToString().Replace('"', '""')
    winget complete --word=$Local:Word --commandline $Local:AST --position $cursorPosition | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Complete-DotFilesSection
