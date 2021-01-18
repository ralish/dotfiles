if ($DotFilesShowScriptEntry) { Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath) }

try {
    if (!$DotFilesFastLoad) {
        Test-ModuleAvailable -Name PSDotFiles
    }
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping PSDotFiles settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading PSDotFiles settings ...')

# Path to our dotfiles directory
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$DotFilesPath = Join-Path -Path $HOME -ChildPath 'dotfiles'

# Enable automatic component detection
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$DotFilesAutodetect = $true

# Allow evaluation of nested symlinks
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$DotFilesAllowNestedSymlinks = $true
