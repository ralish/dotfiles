try {
    Test-ModuleAvailable -Name PSDotFiles
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping PSDotFiles settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading PSDotFiles settings ...')

# Path to our dotfiles directory
$DotFilesPath = Join-Path -Path $HOME -ChildPath 'Code\Personal\dotfiles'

# Enable automatic component detection
$DotFilesAutodetect = $true

# Allow evaluation of nested symlinks
$DotFilesAllowNestedSymlinks = $true
