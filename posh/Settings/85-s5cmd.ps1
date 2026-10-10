# s5cmd
# https://github.com/peak/s5cmd

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 's5cmd'
    Command = 's5cmd'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Initialize s5cmd configuration
Function Initialize-S5Cmd {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'commandAst')]
    [Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'cursorPosition')]
    [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingInvokeExpression', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    Write-DotFilesMessage -Type 'Verbose' -Message 'Registering dynamic argument completer ...'
    Register-ArgumentCompleter -Native -CommandName 's5cmd' -ScriptBlock {
        Param($wordToComplete, $commandAst, $cursorPosition)

        $Completion = "$wordToComplete --generate-bash-completion"
        Invoke-Expression -Command $Completion | ForEach-Object { # DevSkim: ignore DS104456
            [Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
        }
    }
}

Initialize-S5Cmd

Remove-Item -LiteralPath 'Function:\Initialize-S5Cmd'
Complete-DotFilesSection
