# AWS CLI
# https://aws.amazon.com/cli/
# https://github.com/aws/aws-cli

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'AWS CLI'
    Command = 'aws'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Default output format
$Env:AWS_DEFAULT_OUTPUT = 'table'

# Configuring command completion in the AWS CLI
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html
if (Get-Command -Name 'aws_completer' -ErrorAction 'Ignore') {
    Write-DotFilesMessage -Type 'Verbose' -Message 'Registering dynamic argument completer ...'
    Register-ArgumentCompleter -Native -CommandName 'aws' -ScriptBlock {
        Param($wordToComplete, $commandAst, $cursorPosition)

        $Env:COMP_LINE = $commandAst.ToString()
        $Env:COMP_POINT = $cursorPosition

        # `ToString()` in `System.Management.Automation.Language.CommandAst`
        # trims any trailing whitespace from the command which will break our
        # emulated `bash`-style command completion. Append a single whitespace
        # character if the cursor position is beyond the length of the entered
        # command as a simple workaround.
        if ($cursorPosition -gt $Env:COMP_LINE.Length) {
            $Env:COMP_LINE = "${Env:COMP_LINE} "
        }

        & aws_completer | ForEach-Object {
            [Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
        }

        $Env:COMP_LINE = $Env:COMP_POINT = $null
    }
} else {
    Write-DotFilesMessage -Type 'Warning' -Message 'Skipping AWS CLI completion as unable to locate aws_completer.'
}

Complete-DotFilesSection
