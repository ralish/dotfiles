if (!(Get-Command -Name aws -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping AWS CLI settings as unable to locate aws.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading AWS CLI settings ...')

# Configuring the AWS CLI - Command Completion
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html
Register-ArgumentCompleter -Native -CommandName aws -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)
    $env:COMP_LINE = $commandAst.ToString()
    $env:COMP_POINT = $cursorPosition
    aws_completer | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $env:COMP_LINE = $env:COMP_POINT = $null
}
