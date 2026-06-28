# Windows Terminal
# https://learn.microsoft.com/en-au/windows/terminal/
# https://github.com/microsoft/terminal

$DotFilesSection = @{
    Type        = 'Settings'
    Name        = 'Windows Terminal'
    Platform    = 'Windows'
    Environment = @{ WT_SESSION = $true }
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Set the initial state of global variables used by prompt integration
#
# This is only a function because we can't suppress the `PSScriptAnalyzer`
# warning on the usage of global variables outside of one.
Function Set-WindowsTerminalGlobalVariables {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Initial history ID to indicate no previous command has executed
    $Global:__LastHistoryId = -1

    # Preserve the original prompt function for later invocation
    $Global:__OriginalPrompt = $Function:Prompt
}

# Must run before the new `Prompt` function to preserve the original prompt
Set-WindowsTerminalGlobalVariables

# Returns the last exit code for usage by the shell integration
Function Global:__Get-LastExitCodeForWinTerm {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [OutputType([Int])]
    Param(
        [Boolean]$LastCmdStatus
    )

    if ($LastCmdStatus) {
        return 0
    }

    $LastHistoryEntry = Get-History -Count 1
    $IsPowerShellError = $Error[0].InvocationInfo.HistoryId -eq $LastHistoryEntry.Id

    if ($IsPowerShellError) {
        return -1
    }

    return $LASTEXITCODE
}

# Shell Integration
# https://learn.microsoft.com/en-au/windows/terminal/tutorials/shell-integration
Function Global:Prompt {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [OutputType([String])]
    Param()

    # Capture `$?` before invoking `Get-History` as it will reset it. Note that
    # `$LASTEXITCODE` is unaffected as it is only updated for native commands.
    $LastCmdStatus = $?

    # Skip emitting an end of command mark for the first command
    $LastHistoryEntry = Get-History -Count 1
    if ($Global:__LastHistoryId -ne -1) {
        if ($LastHistoryEntry.Id -ne $Global:__LastHistoryId) {
            # Mark end of last command with exit code
            $LastExitCodeForWinTerm = __Get-LastExitCodeForWinTerm -LastCmdStatus $LastCmdStatus
            # `OSC FinalTerm ; CmdEnd ; <ExitCode> ST`
            $Prompt = "$([Char]27)]133;D;${LastExitCodeForWinTerm}`a"
        } else {
            # As above, but without exit code as there's no history entry
            # `OSC FinalTerm ; CmdEnd ST`
            $Prompt = "$([Char]27)]133;D`a"
        }
    }

    # Mark start of prompt
    # `OSC FinalTerm ; PromptStart ST`
    $Prompt += "$([Char]27)]133;A`a"

    # Mark current working directory
    $CurLoc = $ExecutionContext.SessionState.Path.CurrentLocation
    # `OSC ConEmu ; CurrentDir ; "<Cwd>" ST`
    $Prompt += "$([Char]27)]9;9;`"${CurLoc}`"`a"

    # Invoke the original prompt function
    $Prompt += $Global:__OriginalPrompt.Invoke()

    # Mark end of prompt
    # `OSC FinalTerm ; CmdStart ST`
    $Prompt += "$([Char]27)]133;B`a"

    # Save the last history ID for the next invocation
    $Global:__LastHistoryId = $LastHistoryEntry.Id

    return $Prompt
}

Remove-Item -LiteralPath 'Function:\Set-WindowsTerminalGlobalVariables'
Complete-DotFilesSection
