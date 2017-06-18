if (Get-Module -Name PSReadLine -ListAvailable) {
    if ($Host.Name -eq 'ConsoleHost') {
        Import-Module -Name PSReadLine

        # Move the cursor to the end of the line while cycling through history
        Set-PSReadlineOption -HistorySearchCursorMovesToEnd

        # Search the command history based on any already entered text
        Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

        # Bash style command completion
        #Set-PSReadlineKeyHandler -Key Tab -Function Complete
    } else {
        Write-Verbose -Message 'Skipping PSReadLine configuration as host is not ConsoleHost.'
    }
} else {
    Write-Verbose -Message 'Unable to locate PSReadLine module.'
}
