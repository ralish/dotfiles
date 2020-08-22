if (!(Test-IsWindows)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping import of Azure functions.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing Azure functions ...')

# Load our custom formatting data
$null = $FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Azure.format.ps1xml'))

#region Authentication

# Retrieve an Azure AD authorization header
Function Get-AzureAuthHeader {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult]$AuthToken
    )

    $AuthHeader = @{
        Authorization  = $AuthToken.CreateAuthorizationHeader()
        'Content-Type' = 'application/json'
    }

    return $AuthHeader
}

# Retrieve an Azure AD authentication token
# Based on: https://blogs.technet.microsoft.com/paulomarques/2016/04/05/working-with-azure-rest-apis-from-powershell-getting-page-and-block-blob-information-from-arm-based-storage-account-sample-script/
# Useful links:
# - https://blogs.technet.microsoft.com/cloudlojik/2017/09/05/using-powershell-to-connect-to-microsoft-graph-api/
# - https://blogs.technet.microsoft.com/cloudlojik/2018/06/29/connecting-to-microsoft-graph-with-a-native-app-using-powershell/
Function Get-AzureAuthToken {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('AzureAdGraph', 'AzureClassic', 'AzureGallery', 'AzurePortal', 'AzureRm', 'MsGraph')]
        [String]$Api,

        [Parameter(Mandatory)]
        [String]$TenantName,

        # Default is the well-known identifier for PowerShell clients
        [Guid]$ClientId = '1950a258-227b-4e31-a9cf-717495945fc2',

        [ValidateNotNullOrEmpty()]
        [String]$RedirectUri = 'urn:ietf:wg:oauth:2.0:oob',

        [ValidateSet('Auto', 'Always', 'Never', 'RefreshSession', 'SelectAccount')]
        [String]$PromptBehaviour = 'Auto'
    )

    try {
        $ModuleName = 'AzureADPreview'
        Test-ModuleAvailable -Name $ModuleName
    } catch {
        $ModuleName = 'AzureAD'
        Test-ModuleAvailable -Name $ModuleName
    }

    $AdalModule = Get-Module -Name $ModuleName -ListAvailable
    $AdalModulePath = $AdalModule.ModuleBase

    $AdalAsmName = 'Microsoft.IdentityModel.Clients.ActiveDirectory.dll'
    $AdalAsmPath = Join-Path -Path $AdalModulePath -ChildPath $AdalAsmName
    if (Test-Path -LiteralPath $AdalAsmPath) {
        $null = [Reflection.Assembly]::LoadFrom($AdalAsmPath)
    } else {
        throw 'Unable to locate required DLL: {0}' -f $AdalAsmName
    }

    $AdalPlatformAsmName = 'Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll'
    $AdalPlatformAsmPath = Join-Path -Path $AdalModulePath -ChildPath $AdalPlatformAsmName
    if (Test-Path -LiteralPath $AdalPlatformAsmPath) {
        $null = [Reflection.Assembly]::LoadFrom($AdalPlatformAsmPath)
    } else {
        throw 'Unable to locate required DLL: {0}' -f $AdalPlatformAsmName
    }

    switch ($Api) {
        'AzureAdGraph' { $ApiEndpointUri = 'https://graph.windows.net/' }              # Deprecated
        'AzureClassic' { $ApiEndpointUri = 'https://management.core.windows.net/' }    # Deprecated
        'AzureGallery' { $ApiEndpointUri = 'https://gallery.azure.com/' }
        'AzurePortal' { $ApiEndpointUri = '74658136-14ec-4630-ad9b-26e160ff0fc6' }     # Undocumented
        'AzureRm' { $ApiEndpointUri = 'https://management.azure.com/' }
        'MsGraph' { $ApiEndpointUri = 'https://graph.microsoft.com/' }
    }

    $AuthorityUri = 'https://login.microsoftonline.com/{0}.onmicrosoft.com' -f $TenantName
    $AuthContext = New-Object -TypeName 'Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext' -ArgumentList $AuthorityUri
    $PlatformParams = New-Object -TypeName 'Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters' -ArgumentList $PromptBehaviour
    $AuthResult = $AuthContext.AcquireTokenAsync($ApiEndpointUri, $ClientId, $RedirectUri, $PlatformParams)

    return $AuthResult
}

#endregion

#region Reporting

# Retrieve filtered set of Azure AD enterprise applications
#
# The Azure Active Directory -> Enterprise applications pane can return
# a filtered set of results based on whether an application is either a
# "Enterprise Application" or a "Microsoft Application". These options
# aren't exposed via the AzureAD command: Get-AzureADServicePrincipal.
#
# We can get the same functionality within PowerShell by calling the
# undocumented API which the Azure Portal uses.
Function Get-AzureEnterpriseApplications {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult]$AuthToken,

        [ValidateSet('All', 'Enterprise', 'Microsoft')]
        [String]$AppType = 'Enterprise'
    )

    switch ($AppType) {
        'Enterprise' { $AppTypeId = 0 }
        'Microsoft' { $AppTypeId = 1 }
        'All' { $AppTypeId = 2 }
    }

    $Uri = [Uri]::new('https://main.iam.ad.ext.azure.com/api/ManagedApplications/List')

    $Headers = [Ordered]@{
        Authorization            = $AuthToken.CreateAuthorizationHeader()
        'Content-Type'           = 'application/json'
        Host                     = $Uri.Host
        'x-ms-client-request-id' = [Guid]::NewGuid()
    }

    $Body = @{
        appListQuery = $AppTypeId
        top          = 999
    }

    $Params = @{
        Uri     = $Uri.AbsoluteUri
        Method  = 'POST'
        Headers = $Headers
        Body    = ConvertTo-Json $Body
    }

    $Response = Invoke-RestMethod @Params -ErrorAction Stop
    return $Response.appList
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
    [CmdletBinding()]
    Param(
        [Switch]$ReturnAllUsers
    )

    Test-ModuleAvailable -Name MSOnline

    $Users = Get-MsolUser -ErrorAction Stop | Where-Object { $_.IsLicensed -eq $true }

    $Results = [Collections.ArrayList]::new()
    foreach ($User in $Users) {
        $DisabledServices = @($User.Licenses.ServiceStatus | Where-Object { $_.ProvisioningStatus -eq 'Disabled' })

        if ($DisabledServices -or $ReturnAllUsers) {
            $Result = [PSCustomObject]@{
                User    = $User.DisplayName
                Service = [Object[]]$DisabledServices.ServicePlan
            }
            $null = $Results.Add($Result)
        }
    }

    return $Results
}

#endregion

#region Service connection helpers

# Helper function to connect to Azure Active Directory (AzureAD module)
Function Connect-AzureAD {
    [CmdletBinding()]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    $ErrorActionPreference = 'Stop'

    try {
        $ModuleName = 'AzureADPreview'
        Test-ModuleAvailable -Name $ModuleName
    } catch {
        $ModuleName = 'AzureAD'
        Test-ModuleAvailable -Name $ModuleName
    }

    Write-Host -ForegroundColor Green 'Connecting to Azure AD (v2) ...'
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

    $ErrorActionPreference = 'Stop'

    Test-ModuleAvailable -Name AzureRM

    Write-Host -ForegroundColor Green 'Connecting to Azure RM ...'
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

    $ErrorActionPreference = 'Stop'

    Test-ModuleAvailable -Name MSOnline

    Write-Host -ForegroundColor Green 'Connecting to Azure AD (v1) ...'
    Connect-MsolService @PSBoundParameters
}

#endregion
