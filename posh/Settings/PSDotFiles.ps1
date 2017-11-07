if (Get-Module -Name PSDotFiles -ListAvailable) {
    Import-Module -Name PSDotFiles

    # Path to our dotfiles directory
    $DotFilesPath = Join-Path -Path $HOME -ChildPath 'dotfiles'

    # Enable automatic component detection
    $DotFilesAutodetect = $true
} else {
    Write-Verbose -Message 'Unable to locate PSDotFiles module.'
}
