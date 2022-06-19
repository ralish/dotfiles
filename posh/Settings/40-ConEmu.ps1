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
    $prompt = '{0}]9;12{1}' -f [Char]27, [Char]7

    # Let ConEmu know the current working dir
    if ($ExecutionContext.SessionState.Path.CurrentLocation.Provider.Name -eq 'FileSystem') {
        $prompt += '{0}]9;9;"{1}"{2}' -f [Char]27, $ExecutionContext.SessionState.Path.CurrentLocation.Path, [Char]7
    }

    return $prompt
}

Complete-DotFilesSection
