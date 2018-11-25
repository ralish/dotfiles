# Helper function to connect to Azure Active Directory (AzureAD module)
Function Connect-AzureAD {
    [CmdletBinding()]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    Test-ModuleAvailable -Name AzureAD

    Write-Host -ForegroundColor Green -Object 'Connecting to Azure AD (v2) ...'
    AzureAD\Connect-AzureAD @PSBoundParameters
}

# Helper function to connect to Azure Resource Manager
Function Connect-AzureRM {
    [CmdletBinding()]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    Test-ModuleAvailable -Name AzureRM

    Write-Host -ForegroundColor Green -Object 'Connecting to Azure RM ...'
    Login-AzureRmAccount @PSBoundParameters
}

# Helper function to connect to Azure Active Directory (MSOnline module)
Function Connect-MSOnline {
    [CmdletBinding()]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    Test-ModuleAvailable -Name MSOnline

    Write-Host -ForegroundColor Green -Object 'Connecting to Azure AD (v1) ...'
    Connect-MsolService @PSBoundParameters
}

# Retrieve an Azure AD authorization header
Function Get-AzureAuthHeader {
    [CmdletBinding()]
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

# Retrieve an Azure AD authentication token
# Via: https://blogs.technet.microsoft.com/paulomarques/2016/04/05/working-with-azure-rest-apis-from-powershell-getting-page-and-block-blob-information-from-arm-based-storage-account-sample-script/
Function Get-AzureAuthToken {
    [CmdletBinding()]
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
        throw 'Unable to locate required DLL: {0}' -f $AdalAsmName
    }

    $AdalWinFormsAsmName = 'Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll'
    $AdalWinFormsAsmPath = Join-Path -Path $ArmProfileModulePath -ChildPath $AdalWinFormsAsmName
    if (Test-Path -Path $AdalWinFormsAsmPath) {
        $null = [Reflection.Assembly]::LoadFrom($AdalWinFormsAsmPath)
    } else {
        throw 'Unable to locate required DLL: {0}' -f $AdalWinFormsAsmName
    }

    $AuthorityUri = 'https://login.windows.net/{0}' -f $TenantId
    $ApiEndpointUri = 'https://management.core.windows.net/'
    $ClientId = '1950a258-227b-4e31-a9cf-717495945fc2'
    $RedirectUri = 'urn:ietf:wg:oauth:2.0:oob'

    $AuthContext = New-Object -TypeName 'Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext' -ArgumentList $AuthorityUri
    $AuthResult = $AuthContext.AcquireToken($ApiEndpointUri, $ClientId, $RedirectUri, 'Auto')

    return $AuthResult
}

# Retrieve Azure AD users with disabled services
Function Get-AzureUsersWithDisabledServices {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [Switch]$ReturnAllUsers
    )

    Test-ModuleAvailable -Name MSOnline

    $Users = Get-MsolUser -ErrorAction Stop | Where-Object { $_.IsLicensed -eq $true }

    $Results = @()
    foreach ($User in $Users) {
        $DisabledServices = @()
        $DisabledServices += $User.Licenses.ServiceStatus | Where-Object { $_.ProvisioningStatus -eq 'Disabled' }

        if ($DisabledServices -or $ReturnAllUsers) {
            $Results += [PSCustomObject]@{
                'User'=$User.DisplayName
                'Service'=[Object[]]$DisabledServices.ServicePlan
            }
        }
    }

    return $Results
}
