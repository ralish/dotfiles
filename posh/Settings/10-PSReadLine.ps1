if ($Host.Name -ne 'ConsoleHost') {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping PSReadLine settings as host is not ConsoleHost.')
    return
}

try {
    Import-Module -Name PSReadLine -ErrorAction Stop
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping PSReadLine settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading PSReadLine settings ...')

# Don't store duplicate history entries
Set-PSReadLineOption -HistoryNoDuplicates

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

if (Test-IsWindows) {
    if (Get-Command -Name concfg -ErrorAction Ignore) {
        Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading ConCfg settings ...')

        # Set PSReadline colours based on theme
        & concfg tokencolor -n enable
    } else {
        Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ConCfg settings as unable to locate concfg.')
        continue
    }
}
