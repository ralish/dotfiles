if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

if (!$DotFilesFastLoad) {
    try {
        Test-ModuleAvailable -Name PSDotFiles
    } catch {
        Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping PSDotFiles settings as module not found.')
        $Error.RemoveAt(0)
        return
    }
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading PSDotFiles settings ...')

# Path to our dotfiles directory
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesPath = $DotFiles

# Enable automatic component detection
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesAutodetect = $true

# Allow evaluation of nested symlinks
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesAllowNestedSymlinks = $true
