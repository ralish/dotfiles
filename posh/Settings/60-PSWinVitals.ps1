$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'PSWinVitals'
    Platform = 'Windows'
    Module   = @('PSWinVitals')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Get-VitalInformation: Exclude Silverlight updates
$PSDefaultParameterValues['Get-VitalInformation:WUParameters'] = @{ NotTitle = 'Silverlight' }

# Invoke-VitalMaintenance: Exclude Silverlight updates
$PSDefaultParameterValues['Invoke-VitalMaintenance:WUParameters'] = @{ NotTitle = 'Silverlight' }

Complete-DotFilesSection
