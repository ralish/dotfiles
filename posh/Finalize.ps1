# Default to UTF-8 encoding with Out-File
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Number of elements to enumerate when displaying arrays
$FormatEnumerationLimit = 5

# Our custom prompt with various integrations
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
