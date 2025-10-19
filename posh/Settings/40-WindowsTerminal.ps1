$DotFilesSection = @{
    Type           = 'Settings'
    Name           = 'Windows Terminal'
    Platform       = 'Windows'
    PwshMinVersion = '6.0'
    Environment    = @{ WT_SESSION = $true }
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
            $Prompt = "`e]133;D;$LastExitCodeForWinTerm`a"
        } else {
            # As above, but without the exit code if no history entry
            $Prompt = "`e]133;D`a"
        }
    }

    # Mark start of prompt
    $Prompt += "`e]133;A{0}" -f [Char]7

    # Mark current working directory
    $CurLoc = $ExecutionContext.SessionState.Path.CurrentLocation
    $Prompt += "`e]9;9;`"{0}`"{1}" -f $CurLoc, [Char]7

    # Invoke the original prompt function
    $Prompt += $Global:__OriginalPrompt.Invoke()

    # Mark end of prompt
    $Prompt += "`e]133;B{0}" -f [Char]7

    # Save the last history ID for the next invocation
    $Global:__LastHistoryId = $LastHistoryEntry.Id

    return $Prompt
}

Complete-DotFilesSection
