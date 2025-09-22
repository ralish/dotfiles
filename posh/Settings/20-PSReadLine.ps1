$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'PSReadLine'
    PwshHostName    = @('ConsoleHost')
    Module          = @('PSReadLine')
    ModuleOperation = 'Import'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Disable terminal bell
Set-PSReadLineOption -BellStyle None

# Don't store duplicate history entries
Set-PSReadLineOption -HistoryNoDuplicates

# Move the cursor to end of line while cycling through history
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

# Command-line completion prediction sources
#
# PSReadLine picks a sensible default since v2.2.6
# See: https://github.com/PowerShell/PSReadLine/pull/3351
#Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# Search the command history based on any already entered text
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Menu style command completion
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Insert paired parenthesis on line or selection
# Via: https://github.com/lzybkr/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1
$ScriptBlock = {
    Param($Key, $Arg)

    $Line = $null
    $Cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([Ref]$Line, [Ref]$Cursor)

    $SelectionStart = $null
    $SelectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([Ref]$SelectionStart, [Ref]$SelectionLength)

    if ($SelectionStart -ne -1) {
        $SelectionText = $Line.SubString($SelectionStart, $SelectionLength)
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($SelectionStart, $SelectionLength, '({0})' -f $SelectionText)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($SelectionStart + $SelectionLength + 2)
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $Line.Length, '({0})' -f $Line)
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}
$Params = @{
    Chord            = 'Alt+('
    BriefDescription = 'InsertPairedParenthesis'
    LongDescription  = 'Insert parenthesis around the selection or the entire line if no text is selected'
    ScriptBlock      = $ScriptBlock
}
Set-PSReadLineKeyHandler @Params
Remove-Variable -Name 'Params', 'ScriptBlock'

if (!(Test-IsWindows)) {
    # The default for non-Windows platforms is Emacs
    Set-PSReadLineOption -EditMode Vi
}

# We use the Solarized Dark colour scheme for WSL sessions in Windows Terminal.
# Unfortunately, some of PSReadLine's colours are near invisible when used with
# this colour scheme. Switch the affected colours to something more visible.
#
# References:
# - https://github.com/microsoft/terminal/pull/6617
# - https://github.com/microsoft/terminal/pull/6618
# - https://github.com/microsoft/terminal/pull/6489
if ($env:WT_SESSION -and $IsLinux) {
    Set-PSReadLineOption -Colors @{
        Operator  = [ConsoleColor]::Magenta
        Parameter = [ConsoleColor]::Magenta
    }
}

Complete-DotFilesSection
