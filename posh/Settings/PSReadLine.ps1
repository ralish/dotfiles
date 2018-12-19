if (Get-Module -Name PSReadLine -ListAvailable) {
    if ($Host.Name -eq 'ConsoleHost') {
        Write-Verbose -Message '[dotfiles] Loading PSReadLine settings ...'
        Import-Module -Name PSReadLine

        # Move the cursor to end of line while cycling through history
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd

        # Search the command history based on any already entered text
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

        # Menu style command completion
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

        # Insert paired parenthesis on line or selection
        # Via: https://github.com/lzybkr/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1
        Set-PSReadlineKeyHandler `
            -Chord 'Alt+(' `
            -BriefDescription InsertPairedParenthesis `
            -LongDescription 'Insert parenthesis around the selection or the entire line if no text is selected' `
            -ScriptBlock {
                Param($Key, $Arg)

                $Line = $null
                $Cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

                $SelectionStart = $null
                $SelectionLength = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$SelectionStart, [ref]$SelectionLength)

                if ($SelectionStart -ne -1) {
                    $SelectionText = $Line.SubString($SelectionStart, $SelectionLength)
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($SelectionStart, $SelectionLength, '({0})' -f $SelectionText)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($SelectionStart + $SelectionLength + 2)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $Line.Length, '({0})' -f $Line)
                    [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
                }
            }
    } else {
        Write-Verbose -Message '[dotfiles] Skipping PSReadLine settings as host is not ConsoleHost.'
    }
} else {
    Write-Verbose -Message '[dotfiles] Skipping PSReadLine settings as module not found.'
}
