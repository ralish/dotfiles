# s5cmd
# https://github.com/peak/s5cmd

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 's5cmd'
    Command = 's5cmd'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

Write-Verbose -Message (Get-DotFilesMessage 'Registering dynamic argument completer ...')
Register-ArgumentCompleter -Native -CommandName 's5cmd' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)

    $Completion = "$wordToComplete --generate-bash-completion"
    Invoke-Expression -Command $Completion | ForEach-Object { # DevSkim: ignore DS104456
        [System.Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
    }
}

Complete-DotFilesSection
