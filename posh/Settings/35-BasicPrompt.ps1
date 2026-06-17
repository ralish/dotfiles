$DotFilesSection = @{
    Type        = 'Settings'
    Name        = 'Basic Prompt'
    Environment = @{ POSH_SESSION_ID = $false }
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

Function Prompt {
    [OutputType([String])]
    Param()

    $Prompt = ''

    # `posh-git`
    if ($GitPromptScriptBlock) {
        $Prompt += & $GitPromptScriptBlock
    }

    # Default
    if (-not $Prompt) {
        $CurLoc = $ExecutionContext.SessionState.Path.CurrentLocation
        $Prompt = "PS ${CurLoc}$('>' * ($NestedPromptLevel + 1))"
    }

    # ConEmu
    if ($ConEmuPrompt) {
        $Prompt += & $ConEmuPrompt
    }

    return $Prompt
}

Complete-DotFilesSection
