if ((Get-Module PSReadLine -ListAvailable) -and ($Host.Name -eq 'ConsoleHost')) {
    Import-Module PSReadLine

    # Move the cursor to the end of the line while cycling through history
    Set-PSReadlineOption -HistorySearchCursorMovesToEnd

    # Search the command history based on any already entered text
    Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Bash style command completion
    #Set-PSReadlineKeyHandler -Key Tab -Function Complete
} else {
    Write-Verbose "Couldn't locate PSReadLine module; not importing to environment."
}