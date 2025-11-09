$DotFilesSection = @{
    Type        = 'Settings'
    Name        = 'Windows Terminal'
    Platform    = 'Windows'
    Environment = @{ WT_SESSION = $true }
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Shell Integration: PowerShell
# https://learn.microsoft.com/en-us/windows/terminal/tutorials/shell-integration#powershell-pwshexe

# Initial history ID to indicate no previous command has executed
$Global:__LastHistoryId = -1

# Preserve the original prompt function for later invocation
$Global:__OriginalPrompt = $Function:Prompt

Function Global:__Get-LastExitCodeForWinTerm {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    Param()

    if ($? -eq $true) { return 0 }
    $LastHistoryEntry = Get-History -Count 1
    $IsPowerShellError = $Error[0].InvocationInfo.HistoryId -eq $LastHistoryEntry.Id
    if ($IsPowerShellError) { return -1 }
    return $LastExitCode
}

Function Prompt {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    Param()

    # Skip emitting an end of command mark for the first command
    $LastHistoryEntry = Get-History -Count 1
    if ($Global:__LastHistoryId -ne -1) {
        if ($LastHistoryEntry.Id -ne $Global:__LastHistoryId) {
            # Mark the end of the last command including the exit code
            $LastExitCodeForWinTerm = __Get-LastExitCodeForWinTerm
            $Prompt = "{0}]133;D;{1}`a" -f [Char]27, $LastExitCodeForWinTerm
        } else {
            # As above, but without the exit code if no history entry
            $Prompt = "{0}]133;D`a" -f [Char]27
        }
    }

    # Mark start of prompt
    $Prompt += "{0}]133;A`a" -f [Char]27

    # Mark current working directory
    $CurLoc = $ExecutionContext.SessionState.Path.CurrentLocation
    $Prompt += "{0}]9;9;`"{1}`"`a" -f [Char]27, $CurLoc

    # Invoke the original prompt function
    $Prompt += $Global:__OriginalPrompt.Invoke()

    # Mark end of prompt
    $Prompt += "{0}]133;B`a" -f [Char]27

    # Save the last history ID for the next invocation
    $Global:__LastHistoryId = $LastHistoryEntry.Id

    return $Prompt
}

Complete-DotFilesSection
