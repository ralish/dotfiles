Write-Verbose -Message (Get-DotFilesMessage -Message 'Configuring PowerShell ...')

# Number of elements to enumerate when displaying arrays
$FormatEnumerationLimit = 5

# Default to UTF-8 encoding with Out-File
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# PowerShell Core doesn't publish help for the en-GB locale
if ($PSVersionTable.PSEdition -eq 'Core') {
    $PSDefaultParameterValues['Update-Help:UICulture'] = 'en-US'
}

# Save the output of the last command in a variable
# http://get-powershell.com/post/2008/06/25/Stuffing-the-output-of-the-last-command-into-an-automatic-variable.aspx
Function Out-Default {
    $Input | Tee-Object -Variable LastObject | Microsoft.PowerShell.Core\Out-Default
}

# Setup our custom prompt if oh-my-posh is not loaded
if (!(Get-Module -Name oh-my-posh)) {
    Function Prompt {
        $prompt = ''

        # posh-git
        if ($GitPromptScriptBlock) {
            $prompt += & $GitPromptScriptBlock
        }

        # Default
        if (-not $prompt) {
            $prompt = 'PS {0}{1} ' -f $ExecutionContext.SessionState.Path.CurrentLocation, '>' * ($NestedPromptLevel + 1)
        }

        # ConEmu
        if ($ConEmuPrompt) {
            $prompt += & $ConEmuPrompt
        }

        return $prompt
    }
}
