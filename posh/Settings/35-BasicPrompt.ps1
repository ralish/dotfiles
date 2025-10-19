$DotFilesSection = @{
    Type        = 'Settings'
    Name        = 'Basic Prompt'
    Environment = @{
        # Set by Oh My Posh but unclear if stable
        POSH_SESSION_ID = $false
    }
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

Function Prompt {
    $Prompt = [String]::Empty

    # posh-git
    if ($GitPromptScriptBlock) {
        $Prompt += & $GitPromptScriptBlock
    }

    # Default
    if (-not $Prompt) {
        $CurLoc = $ExecutionContext.SessionState.Path.CurrentLocation
        $Prompt = 'PS {0}{1} ' -f $CurLoc, '>' * ($NestedPromptLevel + 1)
    }

    # ConEmu
    if ($ConEmuPrompt) {
        $Prompt += & $ConEmuPrompt
    }

    return $Prompt
}

Complete-DotFilesSection
