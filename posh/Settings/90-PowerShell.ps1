Start-DotFilesSection -Type 'Settings' -Name 'PowerShell'

# Number of elements to enumerate when displaying arrays
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$FormatEnumerationLimit = 5

# Out-File: Default to UTF-8 encoding
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

if ($PSVersionTable.PSEdition -eq 'Core') {
    # Update-Help: en-GB locale is not available under Core
    $PSDefaultParameterValues['Update-Help:UICulture'] = 'en-US'
}

# Save the output of the last command in a variable
# http://get-powershell.com/post/2008/06/25/Stuffing-the-output-of-the-last-command-into-an-automatic-variable.aspx
Function Out-Default {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '')]
    Param()

    $Input | Tee-Object -Variable 'LastObject' | Microsoft.PowerShell.Core\Out-Default
    $Global:LastObject = $LastObject
}

# Setup our custom prompt if Oh My Posh is not loaded
if (!(Get-Command -Name 'oh-my-posh' -ErrorAction Ignore)) {
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

Complete-DotFilesSection
