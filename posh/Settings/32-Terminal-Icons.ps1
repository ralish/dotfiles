# Terminal-Icons
# https://github.com/devblackops/terminal-icons

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Terminal-Icons'
    Module          = 'Terminal-Icons'
    ModuleOperation = 'Import'
    Async           = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

Complete-DotFilesSection
