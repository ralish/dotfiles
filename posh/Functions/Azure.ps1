Function Connect-AzureAD {
    [CmdletBinding()]
    Param(
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (!(Get-Module -Name AzureAD -ListAvailable)) {
        throw 'Required module not available: AzureAD'
    }

    Write-Verbose -Message 'Connecting to Azure AD (v2) ...'
    Import-Module -Name AzureAD
    Azure-AD\Connect-AzureAD @PSBoundParameters
}


Function Connect-AzureRM {
    [CmdletBinding()]
    Param(
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (!(Get-Module -Name AzureRM -ListAvailable)) {
        throw 'Required module not available: AzureRM'
    }

    Write-Verbose -Message 'Connecting to Azure RM ...'
    Import-Module -Name AzureRM
    Login-AzureRmAccount @PSBoundParameters
}


Function Connect-MSOnline {
    [CmdletBinding()]
    Param(
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (!(Get-Module -Name MSOnline -ListAvailable)) {
        throw 'Required module not available: MSOnline'
    }

    Write-Verbose -Message 'Connecting to Azure AD (v1) ...'
    Import-Module -Name MSOnline
    Connect-MsolService @PSBoundParameters
}


Function Get-AzureAuthHeader {
    Param(
        [Parameter(Mandatory)]
        [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult]$AuthToken
    )

    $AuthHeader = @{
        'Content-Type'='application/json'
        'Authorization'=$AuthToken.CreateAuthorizationHeader()
    }

    return $AuthHeader
}


# https://blogs.technet.microsoft.com/paulomarques/2016/04/05/working-with-azure-rest-apis-from-powershell-getting-page-and-block-blob-information-from-arm-based-storage-account-sample-script/
Function Get-AzureAuthToken {
    Param(
        [Parameter(Mandatory)]
        [String]$TenantId
    )

    $ArmProfileModule = Get-Module -Name AzureRM.Profile -ListAvailable
    if ($ArmProfileModule) {
        $ArmProfileModulePath = $ArmProfileModule.ModuleBase
    } else {
        throw 'Required module not available: AzureRM.Profile'
    }

    $AdalAsmName = 'Microsoft.IdentityModel.Clients.ActiveDirectory.dll'
    $AdalAsmPath = Join-Path -Path $ArmProfileModulePath -ChildPath $AdalAsmName
    if (Test-Path -Path $AdalAsmPath) {
        $null = [Reflection.Assembly]::LoadFrom($AdalAsmPath)
    } else {
        throw ('Unable to locate required DLL: {0}' -f $AdalAsmName)
    }

    $AdalFormsAsmName = 'Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll'
    $AdalFormsAsmPath = Join-Path -Path $ArmProfileModulePath -ChildPath $AdalFormsAsmName
    if (Test-Path -Path $AdalFormsAsmPath) {
        $null = [Reflection.Assembly]::LoadFrom($AdalFormsAsmPath)
    } else {
        throw ('Unable to locate required DLL: {0}' -f $AdalFormsAsmName)
    }

    $AuthorityUri = 'https://login.windows.net/{0}' -f $TenantId
    $ApiEndpointUri = 'https://management.core.windows.net/'
    $ClientId = '1950a258-227b-4e31-a9cf-717495945fc2'
    $RedirectUri = 'urn:ietf:wg:oauth:2.0:oob'

    $AuthContext = New-Object -TypeName 'Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext' -ArgumentList $AuthorityUri
    $AuthResult = $AuthContext.AcquireToken($ApiEndpointUri, $ClientId, $RedirectUri, 'Auto')
    return $AuthResult
}


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
