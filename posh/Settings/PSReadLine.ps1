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
    } else {
        Write-Verbose -Message '[dotfiles] Skipping PSReadLine settings as host is not ConsoleHost.'
    }
} else {
    Write-Verbose -Message '[dotfiles] Skipping PSReadLine settings as module not found.'
}
