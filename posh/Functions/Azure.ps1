$DotFilesSection = @{
    Type   = 'Functions'
    Name   = 'Azure'
    Module = 'Microsoft.Graph*'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Azure.format.ps1xml'))

#region Authentication

# Construct a HTTP authorization header for Azure
Function Get-AzureAuthHeader {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    Param(
        # Either:
        # - Microsoft.Azure.Commands.Profile.Models.PSSecureAccessToken (>= 14.0.0)
        # - Microsoft.Azure.Commands.Profile.Models.PSAccessToken (< 14.0.0)
        [Parameter(Mandatory)]
        [PSObject]$AccessToken
    )

    switch ($AccessToken.GetType().FullName) {
        'Microsoft.Azure.Commands.Profile.Models.PSSecureAccessToken' {
            $SecureStringPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken.Token)
            try {
                $BearerToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($SecureStringPtr)
            } finally {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($SecureStringPtr)
            }
        }

        'Microsoft.Azure.Commands.Profile.Models.PSAccessToken' {
            $BearerToken = $AccessToken.Token
        }

        default {
            $ErrMsg = "Unexpected type for AccessToken argument: $($AccessToken.GetType().FullName)"
            $ErrExc = [ArgumentException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidType
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidType', $ErrCat, $AccessToken)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }

    $AuthHeader = @{
        Authorization  = "Bearer ${BearerToken}"
        'Content-Type' = 'application/json'
    }

    return $AuthHeader
}

#endregion

#region Reporting

# Retrieve licensing information for Entra users
Function Get-EntraUserLicenseReport {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType(ParameterSetName = ('Default', 'LicensingInfo'), [PSCustomObject[]])]
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
            $LicensingInfo = @(Import-Csv -LiteralPath $LicensingInfoCsv -ErrorAction 'Stop')
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

        if ($LicensingInfo.Count -eq 0) {
            $ErrMsg = 'Imported licensing information CSV has no entries.'
            $ErrExc = [IO.InvalidDataException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'CsvImportEmpty', $ErrCat, $LicensingInfoCsv)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $ColumnNames = 'Product_Display_Name', 'String_Id', 'Guid', 'Service_Plan_Name', 'Service_Plan_Id', 'Service_Plans_Included_Friendly_Names'
        foreach ($ColumnName in $ColumnNames) {
            if (!($LicensingInfo[0].PSObject.Properties.Name -contains $ColumnName)) {
                $ErrMsg = "Imported CSV is missing expected column: ${ColumnName}"
                $ErrExc = [IO.InvalidDataException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'CsvMissingColumn', $ErrCat, $LicensingInfoCsv)
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
        # Find/replace pairs to clean-up license names
        $LicenseCleanupNameFragments = [Ordered]@{
            '_'                             = ' '
            '\bTEST\b'                      = 'Test'
            '\bTELSTRA\b'                   = 'Telstra'
            '\bGCCHIGH\b'                   = 'GCC High'
            '\bGCCHigh Tenant\b'            = $null
            '\bDOD\b'                       = 'DoD'
            '( GCC High)? USGOV GCC High\b' = ' GCC High'
            '( \(DoD\))? USGOV DoD\b'       = ' DoD'
        }

        # Populate the mapping of license SKU IDs to display names
        $ConflictingNames = 0
        foreach ($Entry in $LicensingInfo) {
            try {
                # Validate format and normalise
                $LicenseSkuId = [Guid]::new($Entry.Guid).ToString()
            } catch {
                $ErrMsg = "Invalid GUID encountered for license entry: $($Entry.Guid)"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'CsvInvalidData', $ErrCat, $Entry.GUID)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            # E.g. `Microsoft 365 E3 (no Teams)`
            $LicenseCandidateName = $Entry.Product_Display_Name

            # Perform initial clean-up of the name
            foreach ($Fragment in $LicenseCleanupNameFragments.Keys) {
                if ($LicenseCandidateName -cmatch $Fragment) {
                    $LicenseCandidateName = $LicenseCandidateName -creplace $Fragment, $LicenseCleanupNameFragments[$Fragment]
                    Write-Debug -Message ('Updating "{0}" to: {1}' -f $Entry.Product_Display_Name, $LicenseCandidateName)
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
            Write-Warning -Message "${ConflictingNames} licenses had conflicting names which were not reconciled."
        }

        if ($ReturnParsedLicenses) {
            return $LicenseSkuIdLookup
        }

        # Find/replace pairs to clean-up service plan names
        $ServicePlanCleanupNameFragments = [Ordered]@{
            '_'                     = ' '
            '\bGCCHigh( Tenant)?\b' = 'GCC High'
            '\bDOD\b'               = 'DoD'
        }

        # Populate the mapping of service plan IDs to display names
        $ConflictingNames = 0
        foreach ($Entry in $LicensingInfo) {
            try {
                # Validate format and normalise
                $ServicePlanId = [Guid]::new($Entry.Service_Plan_Id).ToString()
            } catch {
                $ErrMsg = "Invalid GUID encountered for service plan entry: $($Entry.Service_Plan_Id)"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'CsvInvalidData', $ErrCat, $Entry.Service_Plan_Id)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            # E.g. `Microsoft Entra ID P2`
            $ServicePlanCandidateName = $Entry.Service_Plans_Included_Friendly_Names

            # Perform initial clean-up of the name
            foreach ($Fragment in $ServicePlanCleanupNameFragments.Keys) {
                if ($ServicePlanCandidateName -cmatch $Fragment) {
                    $ServicePlanCandidateName = $ServicePlanCandidateName -creplace $Fragment, $ServicePlanCleanupNameFragments[$Fragment]
                    Write-Debug -Message ('Updating "{0}" to: {1}' -f $Entry.Service_Plans_Included_Friendly_Names, $ServicePlanCandidateName)
                }
            }

            # If the plan ID isn't present add it
            if (!$ServicePlanIdLookup.ContainsKey($ServicePlanId)) {
                $ServicePlanIdLookup[$ServicePlanId] = $ServicePlanCandidateName
                continue
            }

            # Skip identical names
            $ServicePlanCurrentName = $ServicePlanIdLookup[$ServicePlanId]
            if ($ServicePlanCurrentName -ceq $ServicePlanCandidateName) { continue }

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
                # References a plan (e.g. `Plan 2`)
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
            Write-Warning -Message "${ConflictingNames} services had conflicting names which were not reconciled."
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
            Write-Warning -Message "${TitleCaseNames} services had display names converted to title-case."
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
    $UnknownLicenseGuids = [Collections.Generic.List[String]]::new()
    $UnknownServiceGuids = [Collections.Generic.List[String]]::new()

    foreach ($User in $Users) {
        $AssignedLicenses = [Collections.Generic.List[String]]::new()
        $DisabledServices = [Collections.Generic.List[String]]::new()
        $EnabledServices = [Collections.Generic.List[String]]::new()

        # Start by collecting licenses and disabled services
        foreach ($AssignedLicense in $User.AssignedLicenses) {
            $SkuId = $AssignedLicense.SkuId
            $SubscribedSKU = $SubscribedSKUs | Where-Object SkuId -EQ $SkuId
            if (!$SubscribedSKU) {
                Write-Warning -Message ('Skipping unknown license SKU "{0}" assigned to user: {1}' -f $SkuId, $User.UserPrincipalName)
                continue
            }

            $LicenseName = $LicenseSkuIdLookup[$SkuId]
            if (!$LicenseName) {
                if (!$UnknownLicenseGuids.Contains($SkuId)) {
                    Write-Warning -Message "License name is unknown for GUID: ${SkuId}"
                    $UnknownLicenseGuids.Add($SkuId)
                }

                $LicenseName = $SkuId
            }

            $AssignedLicenses.Add($LicenseName)

            foreach ($PlanId in $AssignedLicense.DisabledPlans) {
                $PlanName = $ServicePlanIdLookup[$PlanId]
                if (!$PlanName) {
                    if (!$UnknownServiceGuids.Contains($PlanId)) {
                        Write-Warning -Message "Service name is unknown for GUID: ${PlanId}"
                        $UnknownServiceGuids.Add($PlanId)
                    }

                    $PlanName = $PlanId
                }

                $PlanName = "${LicenseName}:${PlanName}"
                $DisabledServices.Add($PlanName)
            }
        }

        # Enabled services are those which aren't listed in disabled services
        foreach ($AssignedLicense in $User.AssignedLicenses) {
            $SkuId = $AssignedLicense.SkuId
            $SubscribedSKU = $SubscribedSKUs | Where-Object SkuId -EQ $SkuId
            if (!$SubscribedSKU) { continue }

            $LicenseName = $LicenseSkuIdLookup[$SkuId]
            if (!$LicenseName) {
                $LicenseName = $SkuId
            }

            $ServicePlans = $SubscribedSKU.ServicePlans | Where-Object AppliesTo -EQ 'User'
            foreach ($ServicePlan in $ServicePlans) {
                $PlanId = $ServicePlan.ServicePlanId
                $PlanName = $ServicePlanIdLookup[$PlanId]

                if (!$PlanName) {
                    if (!$UnknownServiceGuids.Contains($PlanId)) {
                        Write-Warning -Message "Service name is unknown for GUID: ${PlanId}"
                        $UnknownServiceGuids.Add($PlanId)
                    }

                    $PlanName = $PlanId
                }

                $PlanName = "${LicenseName}:${PlanName}"
                if (!$DisabledServices.Contains($PlanName)) {
                    $EnabledServices.Add($PlanName)
                }
            }
        }

        # If we aren't prefixing each service with the license we need to do
        # some extra work to figure out which services are really disabled.
        if (!$PrefixServicesWithLicense) {
            $EnabledServicesWithLicense = $EnabledServices
            $EnabledServices = [Collections.Generic.List[String]]::new()

            # Strip license prefix and remove duplicate enabled services
            foreach ($EnabledService in $EnabledServicesWithLicense) {
                $ServiceNameOnly = $EnabledService -replace '^.+?:'

                if (!$EnabledServices.Contains($ServiceNameOnly)) {
                    $EnabledServices.Add($ServiceNameOnly)
                }
            }

            $DisabledServicesWithLicense = $DisabledServices
            $DisabledServices = [Collections.Generic.List[String]]::new()

            # Strip license prefix and check if the resulting service name is
            # listed in enabled services. If it is, at least one license has
            # the service enabled. Filter duplicate truly disabled services.
            foreach ($DisabledService in $DisabledServicesWithLicense) {
                $ServiceNameOnly = $DisabledService -replace '^.+?:'
                if ($EnabledServices.Contains($ServiceNameOnly)) { continue }

                if (!$DisabledServices.Contains($ServiceNameOnly)) {
                    $DisabledServices.Add($ServiceNameOnly)
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

Complete-DotFilesSection
