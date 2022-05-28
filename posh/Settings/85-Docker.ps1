$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Docker'
    Command         = @('docker')
    Module          = @('DockerCompletion')
    ModuleOperation = 'Import'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

Complete-DotFilesSection
