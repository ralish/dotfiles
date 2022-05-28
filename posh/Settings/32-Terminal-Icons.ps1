$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Terminal Icons'
    Module          = @('Terminal-Icons')
    ModuleOperation = 'Import'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

Complete-DotFilesSection
