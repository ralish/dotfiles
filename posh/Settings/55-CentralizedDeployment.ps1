# Centralized Deployment
# https://learn.microsoft.com/en-au/microsoft-365/enterprise/use-the-centralized-deployment-powershell-cmdlets-to-manage-add-ins

$DotFilesSection = @{
    Type   = 'Settings'
    Name   = 'Centralized Deployment'
    Module = 'O365CentralizedAddInDeployment'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Add an alias for the unintuitively named `Connect-OrganizationAddInService`
Set-Alias -Name 'Connect-CentralizedDeployment' -Value 'Connect-OrganizationAddInService' -Scope 'Global'

Complete-DotFilesSection
