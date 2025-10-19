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

# Special prompt handling for PowerShell under ConEmu
# See: https://conemu.github.io/en/PowershellPrompt.html
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$ConEmuPrompt = {
    # Let ConEmu know where the prompt ends
    $Prompt = '{0}]9;12{1}' -f [Char]27, [Char]7

    # Let ConEmu know the current working dir
    $CurLoc = $ExecutionContext.SessionState.Path.CurrentLocation
    if ($CurLoc.Provider.Name -eq 'FileSystem') {
        $Prompt += '{0}]9;9;"{1}"{2}' -f [Char]27, $CurLoc, [Char]7
    }

    return $Prompt
}

Complete-DotFilesSection
