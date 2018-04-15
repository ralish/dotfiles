if (Get-Module -Name PSDotFiles -ListAvailable) {
    # Path to our dotfiles directory
    $DotFilesPath = Join-Path -Path $HOME -ChildPath 'dotfiles'

    # Enable automatic component detection
    $DotFilesAutodetect = $true
} else {
    Write-Verbose -Message '[dotfiles] Skipping PSDotFiles settings as module not found.'
}
