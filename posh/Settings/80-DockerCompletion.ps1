# DockerCompletion
# https://github.com/matt9ucci/DockerCompletion

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Docker Completion'
    Command         = 'docker'
    Module          = 'DockerCompletion'
    ModuleOperation = 'Import'
    Async           = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

Complete-DotFilesSection
