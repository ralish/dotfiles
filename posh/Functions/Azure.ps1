if (!(Test-IsWindows)) {
    return
}

# Load our custom formatting data
Update-FormatData -PrependPath (Join-Path -Path $PSScriptRoot -ChildPath 'Azure.format.ps1xml')

# Helper function to connect to Azure Active Directory (AzureAD module)
Function Connect-AzureAD {
    [CmdletBinding()]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (Test-ModuleAvailable -Name AzureADPreview -Return Boolean) {
        $ModuleName = 'AzureADPreview'
    } else {
        Test-ModuleAvailable -Name AzureAD
        $ModuleName = 'AzureAD'
    }

    Write-Host -ForegroundColor Green -Object 'Connecting to Azure AD (v2) ...'
    & $ModuleName\Connect-AzureAD @PSBoundParameters
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
# Based on: https://blogs.technet.microsoft.com/paulomarques/2016/04/05/working-with-azure-rest-apis-from-powershell-getting-page-and-block-blob-information-from-arm-based-storage-account-sample-script/
# Useful links:
# - https://blogs.technet.microsoft.com/cloudlojik/2017/09/05/using-powershell-to-connect-to-microsoft-graph-api/
# - https://blogs.technet.microsoft.com/cloudlojik/2018/06/29/connecting-to-microsoft-graph-with-a-native-app-using-powershell/
Function Get-AzureAuthToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseConsistentWhitespace', '')] # PSScriptAnalyzer bug
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('AzureAdGraph', 'AzureClassic', 'AzureGallery', 'AzureRm', 'MsGraph')]
        [String]$Api,

        [Parameter(Mandatory)]
        [String]$TenantName,

        # Default is the well-known identifier for PowerShell clients
        [Guid]$ClientId='1950a258-227b-4e31-a9cf-717495945fc2',

        [ValidateNotNullOrEmpty()]
        [String]$RedirectUri='urn:ietf:wg:oauth:2.0:oob',

        [ValidateSet('Auto', 'Always', 'Never', 'RefreshSession', 'SelectAccount')]
        [String]$PromptBehaviour='Auto'
    )

    if (Test-ModuleAvailable -Name AzureADPreview -Return Boolean) {
        $AzureADModule = 'AzureADPreview'
    } else {
        Test-ModuleAvailable -Name AzureAD
        $AzureADModule = 'AzureAD'
    }

    $AdalModule = Get-Module -Name $AzureADModule -ListAvailable
    $AdalModulePath = $AdalModule.ModuleBase

    $AdalAsmName = 'Microsoft.IdentityModel.Clients.ActiveDirectory.dll'
    $AdalAsmPath = Join-Path -Path $AdalModulePath -ChildPath $AdalAsmName
    if (Test-Path -Path $AdalAsmPath) {
        $null = [Reflection.Assembly]::LoadFrom($AdalAsmPath)
    } else {
        throw 'Unable to locate required DLL: {0}' -f $AdalAsmName
    }

    $AdalPlatformAsmName = 'Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll'
    $AdalPlatformAsmPath = Join-Path -Path $AdalModulePath -ChildPath $AdalPlatformAsmName
    if (Test-Path -Path $AdalPlatformAsmPath) {
        $null = [Reflection.Assembly]::LoadFrom($AdalPlatformAsmPath)
    } else {
        throw 'Unable to locate required DLL: {0}' -f $AdalPlatformAsmName
    }

    switch ($Api) {
        'MsGraph'           { $ApiEndpointUri = 'https://graph.microsoft.com/' }
        'AzureRm'           { $ApiEndpointUri = 'https://management.azure.com/' }
        'AzureGallery'      { $ApiEndpointUri = 'https://gallery.azure.com/' }
        # Deprecated APIs
        'AzureAdGraph'      { $ApiEndpointUri = 'https://graph.windows.net/' }
        'AzureClassic'      { $ApiEndpointUri = 'https://management.core.windows.net/' }
    }

    $AuthorityUri = 'https://login.microsoftonline.com/{0}.onmicrosoft.com' -f $TenantName
    $AuthContext = New-Object -TypeName 'Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext' -ArgumentList $AuthorityUri
    $PlatformParams = New-Object -TypeName 'Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters' -ArgumentList $PromptBehaviour
    $AuthResult = $AuthContext.AcquireTokenAsync($ApiEndpointUri, $ClientId, $RedirectUri, $PlatformParams)

    return $AuthResult
}

# Retrieve licensing summary for Azure AD users
Function Get-AzureUsersLicensingSummary {
    [CmdletBinding()]
    Param()

    Test-ModuleAvailable -Name MSOnline

    $Users = Get-MsolUser -ErrorAction Stop | Where-Object { $_.UserType -ne 'Guest' }

    foreach ($User in $Users) {
        if ($User.Licenses) {
            $LicensingSummary = [String]::Join(', ', ($User.Licenses.AccountSku.SkuPartNumber | Sort-Object))
        } else {
            $LicensingSummary = [String]::Empty
        }
        Add-Member -InputObject $User -MemberType NoteProperty -Name LicensingSummary -Value $LicensingSummary

        $User.PSObject.TypeNames.Insert(0, 'Microsoft.Online.Administration.User.Licenses')
    }

    return $Users
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
                User        = $User.DisplayName
                Service     = [Object[]]$DisabledServices.ServicePlan
            }
        }
    }

    return $Results
}
