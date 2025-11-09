$DotFilesSection = @{
    Type        = 'Settings'
    Name        = 'ConEmu'
    Platform    = 'Windows'
    Environment = @{ ConEmuANSI = 'ON' }
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Extending PowerShell Prompt
# https://conemu.github.io/en/PowershellPrompt.html
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$ConEmuPrompt = {
    # Mark end of prompt
    # OSC ConEmu ; PromptStart ST
    $Prompt = "{0}]9;12`a" -f [Char]27

    # Mark current working directory
    $CurLoc = $ExecutionContext.SessionState.Path.CurrentLocation
    if ($CurLoc.Provider.Name -eq 'FileSystem') {
        # OSC ConEmu ; CurrentDir ; "<Cwd>" ST
        $Prompt += "{0}]9;9;`"{1}`"`a" -f [Char]27, $CurLoc
    }

    return $Prompt
}

Complete-DotFilesSection
