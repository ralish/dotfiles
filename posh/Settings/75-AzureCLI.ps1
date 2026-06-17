# Azure CLI
# https://learn.microsoft.com/en-au/cli/azure/
# https://github.com/Azure/azure-cli

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'Azure CLI'
    Command = 'az'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Disable telemetry
$Env:AZURE_CORE_COLLECT_TELEMETRY = 'false'

Complete-DotFilesSection
