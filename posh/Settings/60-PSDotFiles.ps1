# PSDotFiles
# https://github.com/ralish/PSDotFiles

$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'PSDotFiles'
    Module   = 'PSDotFiles'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Path to `dotfiles` directory
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesPath = $DotFiles

# Enable automatic component detection
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesAutodetect = $true

# Allow evaluation of nested symlinks
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesAllowNestedSymlinks = $true

Complete-DotFilesSection
