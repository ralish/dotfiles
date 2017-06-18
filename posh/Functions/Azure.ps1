Function Connect-MSOnline {
    [CmdletBinding()]
    Param(
        [System.Management.Automation.Credential()][pscredential]$Credential
    )

    if (!(Get-Module -Name MSOnline -ListAvailable)) {
        throw 'Required module not available: MSOnline'
    }

    Write-Verbose -Message 'Connecting to Azure AD (v1) ...'
    Import-Module -Name MSOnline
    Connect-MsolService @PSBoundParameters
}


Function Connect-AzureAD {
    [CmdletBinding()]
    Param(
        [System.Management.Automation.Credential()][pscredential]$Credential
    )

    if (!(Get-Module -Name AzureAD -ListAvailable)) {
        throw 'Required module not available: AzureAD'
    }

    Write-Verbose -Message 'Connecting to Azure AD (v2) ...'
    Import-Module -Name AzureAD
    Azure-AD\Connect-AzureAD @PSBoundParameters
}


# Find users with disabled services
Function Get-AzureUsersWithDisabledServices {
    $Users = Get-MsolUser | Where-Object { $_.IsLicensed -eq $true}
    foreach ($User in $Users) {
        $DisabledServices = @()
        $LicencedServices = $User.Licenses.ServiceStatus

        foreach ($Service in $LicencedServices) {
            if ($Service.ProvisioningStatus -eq 'Disabled') {
                $DisabledServices += $Service
            }
        }

        if ($DisabledServices.Count -gt 0) {
            Write-Host -Object ('{0} has the following disabled services:' -f $User.DisplayName)
            Write-Host -Object $DisabledServices
            Write-Host -Object ''
        }
    }
}
