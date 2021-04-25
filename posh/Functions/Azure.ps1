if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

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

        # Well-known identifier for PowerShell clients
        [Guid]$ClientId = '1950a258-227b-4e31-a9cf-717495945fc2',

        [ValidateNotNullOrEmpty()]
        [String]$RedirectUri = 'urn:ietf:wg:oauth:2.0:oob',

        [ValidateSet('Auto', 'Always', 'Never', 'RefreshSession', 'SelectAccount')]
        [String]$PromptBehaviour = 'Auto'
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Error -Message 'This function calls assemblies incompatible with PowerShell Core.'
        return
    }

    try {
        $ModuleName = 'AzureADPreview'
        Test-ModuleAvailable -Name $ModuleName
    } catch {
        $ModuleName = 'AzureAD'
        Test-ModuleAvailable -Name $ModuleName
    }

    # Try to handle multiple module versions being present
    $AdalModule = Get-Module -Name $ModuleName | Select-Object -First 1
    if (!$AdalModule) {
        $AdalModule = Get-Module -Name $ModuleName -ListAvailable | Select-Object -First 1
    }

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
    $AuthContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($AuthorityUri)
    $PlatformParams = [Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters]::new($PromptBehaviour)
    $AuthResult = $AuthContext.AcquireTokenAsync($ApiEndpointUri, $ClientId, $RedirectUri, $PlatformParams)

    return $AuthResult
}

#endregion

#region Module management

# Uninstall obsolete Microsoft Graph modules
Function Uninstall-MSGraphObsoleteModules {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    $Modules = Get-Module -Name 'Microsoft.Graph.*' -ListAvailable -Verbose:$false
    $ModuleNames = $Modules | Select-Object -ExpandProperty Name | Sort-Object -Unique
    $UninstallVersions = [Collections.ArrayList]::new()

    foreach ($ModuleName in $ModuleNames) {
        $AllVersions = $Modules | Where-Object Name -EQ $ModuleName
        $LatestVersion = $AllVersions | Sort-Object -Property Version | Select-Object -Last 1
        $ObsoleteVersions = @($AllVersions | Where-Object Version -NE $LatestVersion.Version)

        foreach ($ObsoleteVersion in $ObsoleteVersions) {
            $null = $UninstallVersions.Add($ObsoleteVersion)
        }
    }

    foreach ($UninstallVersion in $UninstallVersions) {
        $NameWithVersion = '{0} {1}' -f $UninstallVersion.Name, $UninstallVersion.Version
        if ($PSCmdlet.ShouldProcess($NameWithVersion, 'Uninstall-Module')) {
            Uninstall-Module -Name $UninstallVersion.Name -RequiredVersion $UninstallVersion.Version -Force
        }
    }
}

#endregion

#region Reporting

# Retrieve filtered set of Azure AD enterprise applications
#
# The Azure AD Enterprise Applications pane can return filtered results
# based on whether a registration is an "Enterprise Application" or a
# "Microsoft Application". These options aren't exposed via the AzureAD
# command: Get-AzureADServicePrincipal. The same functionality can be
# obtained in PowerShell by calling the undocumented Azure Portal API.
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

    $RestMethodParams = @{
        Uri         = $Uri.AbsoluteUri
        Method      = 'POST'
        Headers     = $Headers
        Body        = ($Body | ConvertTo-Json)
        ErrorAction = 'Stop'
    }

    try {
        $Response = Invoke-RestMethod @RestMethodParams
    } catch {
        throw $_
    }

    foreach ($App in $Response.appList) {
        $App.PSObject.TypeNames.Insert(0, 'Microsoft.Azure.Portal.ManagedApplication')
    }

    return $Response.appList
}

# Retrieve licensing summary for Azure AD users
Function Get-AzureUsersLicensingSummary {
    [CmdletBinding()]
    Param()

    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Error -Message 'MSOnline module is incompatible with PowerShell Core.'
        return
    }

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
Function Get-AzureUsersDisabledServices {
    [CmdletBinding()]
    Param(
        [Switch]$ReturnAllUsers
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Error -Message 'MSOnline module is incompatible with PowerShell Core.'
        return
    }

    Test-ModuleAvailable -Name MSOnline

    $Results = [Collections.ArrayList]::new()
    $Users = Get-MsolUser -ErrorAction Stop | Where-Object { $_.IsLicensed -eq $true }

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

    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Error -Message 'AzureAD module is incompatible with PowerShell Core.'
        return
    }

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

    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Error -Message 'AzureRM module is incompatible with PowerShell Core.'
        return
    }

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

    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Error -Message 'MSOnline module is incompatible with PowerShell Core.'
        return
    }

    Test-ModuleAvailable -Name MSOnline

    Write-Host -ForegroundColor Green 'Connecting to Azure AD (v1) ...'
    Connect-MsolService @PSBoundParameters
}

#endregion
