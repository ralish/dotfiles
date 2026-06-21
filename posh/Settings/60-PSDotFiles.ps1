# PSDotFiles
# https://github.com/ralish/PSDotFiles

$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'PSDotFiles'
    Module   = 'PSDotFiles'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup `PSDotFiles` configuration
Function Initialize-PSDotFiles {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Path to `dotfiles` directory
    $Global:DotFilesPath = $DotFiles

    # Enable automatic component detection
    $Global:DotFilesAutodetect = $true

    # Allow evaluation of nested symlinks
    $Global:DotFilesAllowNestedSymlinks = $true
}

Initialize-PSDotFiles

Remove-Item -LiteralPath 'Function:\Initialize-PSDotFiles'
Complete-DotFilesSection
