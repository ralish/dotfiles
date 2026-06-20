# PSReadLine
# https://learn.microsoft.com/en-au/powershell/module/psreadline/
# https://github.com/PowerShell/PSReadLine

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'PSReadLine'
    Module          = 'PSReadLine'
    ModuleOperation = 'Import'
    PwshHostName    = 'ConsoleHost'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup `PSReadLine` configuration
Function Initialize-PSReadLine {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Disable terminal bell
    Set-PSReadLineOption -BellStyle 'None'

    # Don't store duplicate history entries
    Set-PSReadLineOption -HistoryNoDuplicates

    # Move the cursor to end of line when cycling through history
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd

    # Command-line completion prediction sources
    #
    # `PSReadLine` picks a sensible default since v2.2.6
    # https://github.com/PowerShell/PSReadLine/pull/3351
    #Set-PSReadLineOption -PredictionSource 'HistoryAndPlugin'

    if (Test-IsUnix) {
        # The default for non-Windows platforms is Emacs
        Set-PSReadLineOption -EditMode 'Vi'

        # We use the Solarized Dark colour scheme for WSL sessions in Windows
        # Terminal. Unfortunately, some `PSReadLine` colours are near invisible
        # when used with this colour scheme. Switch the affected colours to
        # something more visible.
        #
        # References:
        # - https://github.com/microsoft/terminal/pull/6617
        # - https://github.com/microsoft/terminal/pull/6618
        # - https://github.com/microsoft/terminal/pull/6489
        if ($Env:WT_SESSION) {
            Set-PSReadLineOption -Colors @{
                Operator  = [ConsoleColor]::Magenta
                Parameter = [ConsoleColor]::Magenta
            }
        }
    }

    # Menu style command completion
    Set-PSReadLineKeyHandler -Key 'Tab' -Function 'MenuComplete'

    # Search the command history based on any already entered text
    Set-PSReadLineKeyHandler -Key 'UpArrow' -Function 'HistorySearchBackward'
    Set-PSReadLineKeyHandler -Key 'DownArrow' -Function 'HistorySearchForward'

    # Setup our custom key handlers
    Set-PSReadLineKeyHandlerPairedParenthesis
}

# Insert paired parenthesis on line or selection
Function Set-PSReadLineKeyHandlerPairedParenthesis {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $KeyHandlerScript = {
        Param($Key, $Arg)

        $Line = $null
        $Cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([Ref]$Line, [Ref]$Cursor)

        $SelectionStart = $null
        $SelectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([Ref]$SelectionStart, [Ref]$SelectionLength)

        if ($SelectionStart -ne -1) {
            $SelectionText = $Line.SubString($SelectionStart, $SelectionLength)
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($SelectionStart, $SelectionLength, "(${SelectionText})")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($SelectionStart + $SelectionLength + 2)
        } else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $Line.Length, "(${Line})")
            [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
        }
    }

    $KeyHandlerParams = @{
        Chord            = 'Alt+('
        BriefDescription = 'InsertPairedParenthesis'
        LongDescription  = 'Insert parenthesis around the selection or the entire line if no text is selected'
        ScriptBlock      = $KeyHandlerScript
    }

    Set-PSReadLineKeyHandler @KeyHandlerParams
}

Initialize-PSReadLine

Remove-Item -LiteralPath 'Function:\Initialize-PSReadLine', 'Function:\Set-PSReadLineKeyHandlerPairedParenthesis'
Complete-DotFilesSection
