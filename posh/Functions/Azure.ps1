$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Azure'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Azure.format.ps1xml'))

#region Authentication

# Retrieve an Azure AD authorization header
Function Get-AzureAuthHeader {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    Param(
        [Parameter(Mandatory)]
        [Object]$AuthToken
    )

    try {
        $CorrectType = $AuthToken -is [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult]
    } catch {
        throw 'Unable to locate Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult type.'
    }

    if (!$CorrectType) {
        throw 'AuthToken must be an Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult type.'
    }

    $AuthHeader = @{
        Authorization  = $AuthToken.CreateAuthorizationHeader()
        'Content-Type' = 'application/json'
    }

    return $AuthHeader
}

# Retrieve an Azure AD authentication token
#
# Working with Azure REST APIs from Powershell - Getting page and block blob information from ARM based storage account sample script
# https://learn.microsoft.com/en-au/archive/blogs/paulomarques/working-with-azure-rest-apis-from-powershell-getting-page-and-block-blob-information-from-arm-based-storage-account-sample-script
#
# Using PowerShell to Connect to Microsoft Graph API
# https://learn.microsoft.com/en-au/archive/blogs/cloudlojik/using-powershell-to-connect-to-microsoft-graph-api
#
# Connecting to Microsoft Graph with a Native App using PowerShell
# https://learn.microsoft.com/en-au/archive/blogs/cloudlojik/connecting-to-microsoft-graph-with-a-native-app-using-powershell
Function Get-AzureAuthToken {
    [CmdletBinding()]
    [OutputType([Threading.Tasks.Task])]
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
        throw 'This function calls assemblies incompatible with PowerShell Core.'
    }

    try {
        $ModuleName = 'AzureADPreview'
        Test-ModuleAvailable -Name $ModuleName
    } catch {
        $ModuleName = 'AzureAD'
        Test-ModuleAvailable -Name $ModuleName
    }

    # Try to handle multiple module versions being present
    $AdalModule = Get-Module -Name $ModuleName -Verbose:$false | Select-Object -First 1
    if (!$AdalModule) {
        $AdalModule = Get-Module -Name $ModuleName -ListAvailable -Verbose:$false | Select-Object -First 1
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

#region Reporting

# Retrieve filtered set of Azure AD enterprise applications
#
# The Azure AD Enterprise Applications pane can filter results on whether a
# registration is an "Enterprise Application" or a "Microsoft Application".
# These options aren't exposed via the AzureAD PowerShell module command:
# `Get-AzureADServicePrincipal`. The same functionality can be obtained in
# PowerShell by calling the undocumented Azure Portal API.
Function Get-AzureEnterpriseApplications {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory)]
        [Object]$AuthToken,

        [ValidateSet('All', 'Enterprise', 'Microsoft')]
        [String]$AppType = 'Enterprise'
    )

    try {
        $CorrectType = $AuthToken -is [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult]
    } catch {
        throw 'Unable to locate Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult type.'
    }

    if (!$CorrectType) {
        throw 'AuthToken must be an Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationResult type.'
    }

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
        Verbose     = $false
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

# Retrieve licensing information for Entra users
Function Get-EntraUserLicenseReport {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSCustomObject[]])]
    [OutputType(ParameterSetName = ('ParsedLicenses', 'ParsedServices'), [Hashtable])]
    Param(
        # Product names and service plan identifiers for licensing
        # https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference
        [Parameter(ParameterSetName = 'LicensingInfo', Mandatory)]
        [Parameter(ParameterSetName = 'ParsedLicenses', Mandatory)]
        [Parameter(ParameterSetName = 'ParsedServices', Mandatory)]
        [String]$LicensingInfoCsv,

        [Switch]$PrefixServicesWithLicense,

        [Parameter(ParameterSetName = 'ParsedLicenses', Mandatory)]
        [Switch]$ReturnParsedLicenses,

        [Parameter(ParameterSetName = 'ParsedServices', Mandatory)]
        [Switch]$ReturnParsedServices
    )

    $RequiredModules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Identity.DirectoryManagement'
        'Microsoft.Graph.Users'
    )
    Test-ModuleAvailable -Name $RequiredModules

    if ($LicensingInfoCsv) {
        try {
            $LicensingInfo = Import-Csv -LiteralPath $LicensingInfoCsv -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

        if ($LicensingInfo.Count -eq 0) {
            $ErrMsg = 'Imported licensing information CSV has no entries.'
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
            $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'CsvImportEmpty', $ErrCat, $LicensingInfoCsv)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $ColumnNames = 'Product_Display_Name', 'String_Id', 'Guid', 'Service_Plan_Name', 'Service_Plan_Id', 'Service_Plans_Included_Friendly_Names'
        foreach ($ColumnName in $ColumnNames) {
            if (!($LicensingInfo[0].PSObject.Properties.Name -contains $ColumnName)) {
                $ErrMsg = "Imported CSV is missing expected column: ${ColumnName}"
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'CsvMissingColumn', $ErrCat, $LicensingInfoCsv)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }
        }
    }

    # Scopes to request if there's no existing context or missing scopes
    $DefaultScopes = 'User.Read.All', 'LicenseAssignment.Read.All'
    # Acceptable user scopes
    $UserScopes = 'User.Read.All', 'Directory.Read.All'
    # Acceptable licensing scopes
    $LicensingScopes = 'LicenseAssignment.Read.All', 'Organization.Read.All', 'Directory.Read.All'

    # Check any existing context has acceptable scopes
    $MgContext = Get-MgContext
    $HasRequiredScopes = $false
    if ($MgContext) {
        $HasUserScope = $false
        foreach ($Scope in $UserScopes) {
            if ($Scope -in $MgContext.Scopes) {
                $HasUserScope = $true
                break
            }
        }

        $HasLicensingScope = $false
        foreach ($Scope in $LicensingScopes) {
            if ($Scope -in $MgContext.Scopes) {
                $HasLicensingScope = $true
                break
            }
        }

        $HasRequiredScopes = $HasUserScope -and $HasLicensingScope
    }

    if (!$HasRequiredScopes) {
        try {
            Write-Verbose -Message 'Connecting to Microsoft Graph ...'
            Connect-MgGraph -Scopes $DefaultScopes -NoWelcome -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }

    try {
        Write-Verbose -Message 'Retrieving subscribed licensing SKUs ...'
        $SubscribedSKUs = Get-MgSubscribedSku -All -ErrorAction 'Stop' | Where-Object AppliesTo -EQ 'User'

        Write-Verbose -Message 'Retrieving user license assignments ...'
        $Users = Get-MgUser -All -Property 'Id', 'UserPrincipalName', 'DisplayName', 'AssignedLicenses' -ErrorAction 'Stop'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    $LicenseSkuIdLookup = @{}
    $ServicePlanIdLookup = @{}

    if ($LicensingInfoCsv) {
        # Populate the mapping of license SKU IDs to display names
        $ConflictingNames = 0
        foreach ($Entry in $LicensingInfo) {
            # E.g. dcf0408c-aaec-446c-afd4-43e3683943ea
            $LicenseSkuId = [Guid]::new($Entry.Guid)
            # E.g. Microsoft 365 E3 (no Teams)
            $LicenseCandidateName = $Entry.Product_Display_Name
            # Find/replace pairs to clean-up names
            $CleanupNameFragments = [Ordered]@{
                '_'                             = ' '
                '\bTEST\b'                      = 'Test'
                '\bTELSTRA\b'                   = 'Telstra'
                '\bGCCHIGH\b'                   = 'GCC High'
                '\bGCCHigh Tenant\b'            = $null
                '\bDOD\b'                       = 'DoD'
                '( GCC High)? USGOV GCC High\b' = ' GCC High'
                '( \(DoD\))? USGOV DoD\b'       = ' DoD'
            }

            # Perform initial clean-up of the name
            foreach ($Fragment in $CleanupNameFragments.Keys) {
                if ($LicenseCandidateName -cmatch $Fragment) {
                    $LicenseCandidateName = $LicenseCandidateName -creplace $Fragment, $CleanupNameFragments[$Fragment]
                    Write-Debug -Message 'Updating "{0}" to: {1}' -f $Entry.Product_Display_Name, $LicenseCandidateName
                }
            }

            # If the license SKU isn't present add it
            if (!$LicenseSkuIdLookup.ContainsKey($LicenseSkuId)) {
                $LicenseSkuIdLookup[$LicenseSkuId] = $LicenseCandidateName
                continue
            }

            # Skip identical names
            $LicenseCurrentName = $LicenseSkuIdLookup[$LicenseSkuId]
            if ($LicenseCurrentName -ceq $LicenseCandidateName) { continue }

            # Prefer name which does not reference an outdated license name:
            # - Power Virtual Agent(s) -> Copilot Studio
            $TestRegex = '\b(Power Virtual Agents?)\b'
            if ($LicenseCandidateName -match $TestRegex) { continue }
            if ($LicenseCurrentName -match $TestRegex) {
                $LicenseSkuIdLookup[$LicenseSkuId] = $LicenseCandidateName
                continue
            }

            $ConflictingNames++
            Write-Debug -Message ('Display name for license "{0}" differs from existing entry: {1} != {2}' -f $LicenseSkuId, $LicenseCurrentName, $LicenseCandidateName)
        }

        if ($ConflictingNames) {
            Write-Warning "${ConflictingNames} licenses had conflicting names which were not reconciled."
        }

        if ($ReturnParsedLicenses) {
            return $LicenseSkuIdLookup
        }

        # Populate the mapping of service plan IDs to display names
        $ConflictingNames = 0
        foreach ($Entry in $LicensingInfo) {
            # E.g. eec0eb4f-6444-4f95-aba0-50c24d67f998
            $ServicePlanId = $Entry.Service_Plan_Id
            # E.g. Microsoft Entra ID P2
            $ServicePlanCandidateName = $Entry.Service_Plans_Included_Friendly_Names
            # Find/replace pairs to clean-up names
            $CleanupNameFragments = [Ordered]@{
                '_'                     = ' '
                '\bGCCHigh( Tenant)?\b' = 'GCC High'
                '\bDOD\b'               = 'DoD'
            }

            # Perform initial clean-up of the name
            foreach ($Fragment in $CleanupNameFragments.Keys) {
                if ($LicenseCandidateName -cmatch $Fragment) {
                    $ServicePlanCandidateName = $ServicePlanCandidateName -creplace $Fragment, $CleanupNameFragments[$Fragment]
                    Write-Debug -Message 'Updating "{0}" to: {1}' -f $Entry.Service_Plans_Included_Friendly_Names, $ServicePlanCandidateName
                }
            }

            # If the plan ID isn't present add it
            if (!$ServicePlanIdLookup.ContainsKey($ServicePlanId)) {
                $ServicePlanIdLookup[$ServicePlanId] = $ServicePlanCandidateName
                continue
            }

            # Skip identical names
            $LicenseCurrentName = $LicenseSkuIdLookup[$LicenseSkuId]
            if ($LicenseCurrentName -ceq $LicenseCandidateName) { continue }

            $ServicePlanCurrentName = $ServicePlanIdLookup[$ServicePlanId]
            $UpdatedCurrentName = $false
            $IgnoredCandidateName = $false

            # Prefer name which is not upper-case
            if ($ServicePlanCandidateName -ceq $ServicePlanCandidateName.ToUpper()) { continue }
            if ($ServicePlanCurrentName -ceq $ServicePlanCurrentName.ToUpper()) {
                $ServicePlanIdLookup[$ServicePlanId] = $ServicePlanCandidateName
                $UpdatedCurrentName = $true
            }

            # Prefer name which does not contain specific capitalised words
            $TestRegex = '\b(EDU|RIGHTS)\b'
            if ($ServicePlanCandidateName -cmatch $TestRegex) { continue }
            if ($ServicePlanCurrentName -cmatch $TestRegex) {
                $ServicePlanIdLookup[$ServicePlanId] = $ServicePlanCandidateName
                $UpdatedCurrentName = $true
            }

            # Replace current name with candidate name if the candidate name
            # does not match the regex but the current name does.
            $CandidateNoMatchRegexes = @(
                # Grammar/spelling mistakes
                '\b(Microsoft Microsoft|PowerApps)\b'
                # Deprecated services
                '\b(Do Not Use|Retired)\b'
                # Outdated service names:
                # - Azure      -> Entra
                # - Flow       -> Power Automate
                # - Office 365 -> Microsoft 365
                '\b(Azure|Flow|O(ffice )?365)\b'
            )

            foreach ($TestRegex in $CandidateNoMatchRegexes) {
                if ($ServicePlanCandidateName -match $TestRegex) {
                    $IgnoredCandidateName = $true
                    break
                }

                if ($ServicePlanCurrentName -match $TestRegex) {
                    $ServicePlanIdLookup[$ServicePlanId] = $ServicePlanCandidateName
                    $UpdatedCurrentName = $true
                }
            }

            if ($IgnoredCandidateName) { continue }

            # Replace current name with candidate name if the current name
            # does not match the regex but the candidate name does not.
            $CandidateMatchRegexes = @(
                # References a plan (e.g. Plan 2)
                '\bPlan\b'
            )

            foreach ($TestRegex in $CandidateMatchRegexes) {
                if ($ServicePlanCurrentName -match $TestRegex) {
                    $IgnoredCandidateName = $true
                    break
                }

                if ($ServicePlanCandidateName -match $TestRegex) {
                    $ServicePlanIdLookup[$ServicePlanId] = $ServicePlanCandidateName
                    $UpdatedCurrentName = $true
                }
            }

            if ($IgnoredCandidateName -or $UpdatedCurrentName) { continue }

            $ConflictingNames++
            Write-Debug -Message ('Display name for service "{0}" differs from existing entry: {1} != {2}' -f $ServicePlanId, $ServicePlanCurrentName, $ServicePlanCandidateName)
        }

        if ($ConflictingNames) {
            Write-Warning "${ConflictingNames} services had conflicting names which were not reconciled."
        }

        # Convert remaining names which are entirely upper-case to title-case
        $TitleCaseNames = 0
        $CultureTextInfo = (Get-Culture).TextInfo
        foreach ($ServicePlanId in $($ServicePlanIdLookup.Keys)) {
            $ServicePlanName = $ServicePlanIdLookup[$ServicePlanId]
            if ($ServicePlanName -cne $ServicePlanName.ToUpper()) { continue }

            # Convert to lower-case first as `ToTitleCase()` treats upper-case
            # words as acronyms and skips processing them.
            $ServicePlanIdLookup[$ServicePlanId] = $CultureTextInfo.ToTitleCase($ServicePlanName.ToLower())
            $TitleCaseNames++
        }

        if ($TitleCaseNames) {
            Write-Warning -Message "${TitleCaseNames} service had display names converted to title-case."
        }

        if ($ReturnParsedServices) {
            return $ServicePlanIdLookup
        }
    } else {
        # Populate the mapping of license SKU IDs to names
        foreach ($SubscribedSKU in $SubscribedSKUs) {
            $LicenseSkuIdLookup[$SubscribedSKU.SkuId] = $SubscribedSKU.SkuPartNumber

            # Populate the mapping of service plan IDs to names
            foreach ($ServicePlan in $SubscribedSKU.ServicePlans) {
                $ServicePlanIdLookup[$ServicePlan.ServicePlanId] = $ServicePlan.ServicePlanName
            }
        }
    }

    $Results = [Collections.Generic.List[PSCustomObject]]::new()
    foreach ($User in $Users) {
        $AssignedLicenses = [Collections.Generic.List[String]]::new()
        $DisabledServices = [Collections.Generic.List[String]]::new()
        $EnabledServices = [Collections.Generic.List[String]]::new()

        foreach ($AssignedLicense in $User.AssignedLicenses) {
            $SubscribedSKU = $SubscribedSKUs | Where-Object SkuId -EQ $AssignedLicense.SkuId
            $ServicePlans = $SubscribedSKU.ServicePlans | Where-Object AppliesTo -EQ 'User'

            $LicenseName = $LicenseSkuIdLookup[$SubscribedSKU.SkuId]
            $AssignedLicenses.Add($LicenseName)

            foreach ($PlanId in $AssignedLicense.DisabledPlans) {
                $PlanName = $ServicePlanIdLookup[$PlanId]
                if ($PrefixServicesWithLicense) {
                    $PlanName = "${LicenseName}:${PlanName}"
                }

                $DisabledServices.Add($PlanName)
            }

            foreach ($ServicePlan in $ServicePlans) {
                $PlanName = $ServicePlanIdLookup[$ServicePlan.ServicePlanId]
                if ($PrefixServicesWithLicense) {
                    $PlanName = "${LicenseName}:${PlanName}"
                }

                if ($PlanName -notin $DisabledServices) {
                    $EnabledServices.Add($PlanName)
                }
            }
        }

        $Result = [PSCustomObject]@{
            UserPrincipalName = $User.UserPrincipalName
            DisplayName       = $User.DisplayName
            AssignedLicenses  = [String[]]@($AssignedLicenses | Sort-Object)
            EnabledServices   = [String[]]@($EnabledServices | Sort-Object -Unique)
            DisabledServices  = [String[]]@($DisabledServices | Sort-Object -Unique)
        }
        $Result.PSObject.TypeNames.Insert(0, 'Microsoft.Entra.User.LicenseReport')
        $Results.Add($Result)
    }

    return $Results.ToArray()
}

#endregion

#region Service connection helpers

# Helper function to connect to Azure Active Directory (AzureAD module)
Function Connect-AzureAD {
    [CmdletBinding()]
    #[OutputType([Microsoft.Open.Azure.AD.CommonLibrary.PSAzureContext])]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'AzureAD module is incompatible with PowerShell Core.'
    }

    # Both modules may be present but the `AzureAD` module is newer. Often this
    # is due to a specific version of the `AzureADPreview` module being listed
    # as a dependency in another module which has yet to be updated. As such,
    # we shouldn't naively import `AzureADPreview` assuming it's the latest.
    $ModuleNames = 'AzureAD', 'AzureADPreview'
    $CandidateModules = Get-Module -Name $ModuleNames -ListAvailable -Verbose:$false
    if (!$CandidateModules) {
        # Redundant but ensures consistent error messages
        Test-ModuleAvailable -Name $ModuleNames -Require Any
    }

    $Module = $CandidateModules | Sort-Object -Property 'Version' | Select-Object -Last 1
    $ModuleName = $Module.Name

    Write-Host -ForegroundColor Green 'Connecting to Azure AD (v2) ...'
    & $ModuleName\Connect-AzureAD @PSBoundParameters
}

# Helper function to connect to Azure Resource Manager
Function Connect-AzureRM {
    [CmdletBinding()]
    #[OutputType([Microsoft.Azure.Commands.Profile.Models.PSAzureProfile])]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'AzureRM module is incompatible with PowerShell Core.'
    }

    Test-ModuleAvailable -Name 'AzureRM'

    Write-Host -ForegroundColor Green 'Connecting to Azure RM ...'
    Login-AzureRmAccount @PSBoundParameters
}

# Helper function to connect to Azure Active Directory (MSOnline module)
Function Connect-MSOnline {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'MSOnline module is incompatible with PowerShell Core.'
    }

    Test-ModuleAvailable -Name 'MSOnline'

    Write-Host -ForegroundColor Green 'Connecting to Azure AD (v1) ...'
    Connect-MsolService @PSBoundParameters
}

#endregion

Complete-DotFilesSection
