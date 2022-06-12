$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'AWS CLI'
    Command = @('aws')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Output format
$env:AWS_DEFAULT_OUTPUT = 'table'

# Configuring the AWS CLI - Command Completion
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html
if (Get-Command -Name 'aws_completer' -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName 'aws' -ScriptBlock {
        Param($wordToComplete, $commandAst, $cursorPosition)
        $env:COMP_LINE = $commandAst.ToString()
        $env:COMP_POINT = $cursorPosition

        # ToString() in System.Management.Automation.Language.CommandAst trims
        # trailing whitespace from the command, which breaks our emulated bash
        # style command completion. Handle it by appending a single whitespace
        # character if the cursor position is greater than the command length.
        if ($cursorPosition -gt $env:COMP_LINE.Length) {
            $env:COMP_LINE = '{0} ' -f $env:COMP_LINE
        }

        aws_completer | ForEach-Object {
            [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }

        $env:COMP_LINE = $env:COMP_POINT = $null
    }
} else {
    Write-Warning -Message (Get-DotFilesMessage -Message 'Skipping AWS CLI completion as unable to locate aws_completer.')
}

Complete-DotFilesSection
