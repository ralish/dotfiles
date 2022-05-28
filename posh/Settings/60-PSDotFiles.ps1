$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'PSDotFiles'
    Platform = 'Windows'
    Module   = @('PSDotFiles')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Path to our dotfiles directory
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesPath = $DotFiles

# Enable automatic component detection
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesAutodetect = $true

# Allow evaluation of nested symlinks
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesAllowNestedSymlinks = $true

Complete-DotFilesSection
