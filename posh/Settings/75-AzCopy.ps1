# AzCopy
# https://learn.microsoft.com/en-au/azure/storage/common/storage-use-azcopy-v10
# https://github.com/Azure/azure-storage-azcopy

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'AzCopy'
    Command = 'azcopy'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Disable logging to the system log
$Env:AZCOPY_DISABLE_SYSLOG = 'true'

Complete-DotFilesSection
