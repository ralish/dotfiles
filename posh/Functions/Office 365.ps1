$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Office 365'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Office 365.format.ps1xml'))

#region Cloud App Security

# Compare Cloud App Security policies
Function Compare-MCASPolicy {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[][]])]
    Param(
        [Parameter(Mandatory)]
        [PSObject[]]$ReferenceObject,

        [Parameter(Mandatory)]
        [PSObject[]]$DifferenceObject
    )

    $IgnoredProperties = @(
        '_id'
        '_tid'
        'created'
        'createdBy'
        'lastEntityModificationScanned'
        'lastModified'
        'lastNrtEntityModificationScanned'
        'lastScanned'
        'lastStateModified'
        'lastStateModifiedBy'
        'lastUserModified'
        'ref_policy_created'
        'ruleVersionId'
    )

    $Results = [Collections.Generic.List[PSCustomObject]]::new()

    foreach ($RefPol in ($ReferenceObject | Sort-Object -Property name)) {
        if (!$RefPol.ref_policy_id) {
            Write-Warning -Message ('[ID: {0}] Reference policy with no reference policy ID.' -f $RefPol._id)
            continue
        }

        $DiffPol = $DifferenceObject | Where-Object ref_policy_id -EQ $RefPol.ref_policy_id
        if (!$DiffPol) {
            Write-Warning -Message ('[ID: {0}] Reference policy with no associated difference policy (Ref Policy ID: {1}).' -f $RefPol._id, $RefPol.ref_policy_id)
            continue
        }

        $Diff = Compare-ObjectProperties -ReferenceObject $RefPol -DifferenceObject $DiffPol -IgnoredProperties $IgnoredProperties
        if ($Diff) {
            $PolicyName = [PSCustomObject]@{
                PropertyName = 'policyName'
                RefValue     = $RefPol.name
                DiffValue    = $DiffPol.name
            }

            $RefPolicyId = [PSCustomObject]@{
                PropertyName = 'ref_policy_id'
                RefValue     = $RefPol.ref_policy_id
                DiffValue    = $DiffPol.ref_policy_id
            }

            $Result = @($PolicyName, $RefPolicyId, $Diff)
            $Results.Add($Result)
        }
    }

    foreach ($DiffPol in ($DifferenceObject | Sort-Object -Property name)) {
        if (!$DiffPol.ref_policy_id) {
            Write-Warning -Message ('[ID: {0}] Difference policy with no reference policy ID.' -f $DiffPol._id)
            continue
        }

        $RefPol = $ReferenceObject | Where-Object ref_policy_id -EQ $DiffPol.ref_policy_id
        if (!$RefPol) {
            Write-Warning -Message ('[ID: {0}] Difference policy with no associated reference policy (Ref Policy ID: {1}).' -f $DiffPol._id, $DiffPol.ref_policy_id)
            continue
        }
    }

    return $Results.ToArray()
}

#endregion

#region Exchange Online

# Export mailbox data for our email management spreadsheet
Function Export-MailboxSpreadsheetData {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Mailbox,

        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [DateTime]$StartDate,
        [DateTime]$EndDate,
        [Switch]$SkipActivitySummary,

        [ValidateNotNullOrEmpty()]
        [String]$DescriptionTimeZone = 'AUS Eastern Standard Time',

        [ValidateNotNullOrEmpty()]
        [String]$DescriptionTimeFormat = 'yyyy/mm/dd'
    )

    Test-CommandAvailable -Name Get-Mailbox

    if (!$Path) {
        if ((Get-Item -LiteralPath $PWD -ErrorAction Ignore) -is [IO.DirectoryInfo]) {
            $Path = $PWD
        } else {
            Write-Warning -Message 'Defaulting to $HOME as $PWD is not a directory.'
            $Path = $HOME
        }
    }

    $ExportDir = Get-Item -LiteralPath $Path -ErrorAction Ignore
    if ($ExportDir -isnot [IO.DirectoryInfo]) {
        throw 'Provided path is not a directory: {0}' -f $Path
    }

    $WriteProgressParams = @{
        Activity = 'Exporting mailbox data to spreadsheet'
    }

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox details' -PercentComplete 1
    $ExoMailbox = Get-Mailbox -Identity $Mailbox
    $MailboxAddress = $ExoMailbox.PrimarySmtpAddress

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox rules' -PercentComplete 20
    $Rules = Get-InboxRule -DescriptionTimeZone $DescriptionTimeZone -DescriptionTimeFormat $DescriptionTimeFormat
    foreach ($Rule in $Rules) {
        $Rule.Description = $Rule.Description -replace '\r?\n\r?\Z$'
    }

    if (!$SkipActivitySummary) {
        $Params = @{ Mailbox = $Mailbox }
        foreach ($Parameter in @('StartDate', 'EndDate')) {
            if ($PSBoundParameters.ContainsKey($Parameter)) {
                $Params.Add($Parameter, $PSBoundParameters.Item($Parameter))
            }
        }

        Write-Progress @WriteProgressParams -Status 'Retrieving mailbox activity summary' -PercentComplete 40
        $Activity = Get-MailboxActivitySummary -Mailbox $Mailbox
    }

    Write-Progress @WriteProgressParams -Status 'Retrieving inbox rules by folders' -PercentComplete 60
    $Folders = Get-InboxRulesByFolders -Mailbox $Mailbox -DescriptionTimeZone $DescriptionTimeZone -DescriptionTimeFormat $DescriptionTimeFormat

    Write-Progress @WriteProgressParams -Status 'Exporting mailbox data' -PercentComplete 80
    $ExportCsvParams = @{
        Encoding          = 'UTF8'
        NoTypeInformation = $true
    }

    if (!$SkipActivitySummary) {
        $Activity | Export-Csv -LiteralPath (Join-Path -Path $Path -ChildPath 'Activity Summary.csv') -Append @ExportCsvParams
    }

    $Folders | Export-Csv -LiteralPath (Join-Path -Path $Path -ChildPath ('{0} - Folders.csv' -f $MailboxAddress)) @ExportCsvParams
    $Rules | Export-Csv -LiteralPath (Join-Path -Path $Path -ChildPath ('{0} - Rules.csv' -f $MailboxAddress)) @ExportCsvParams

    Write-Progress @WriteProgressParams -Completed
}

# Retrieve a summary of mailbox folders with associated rules
Function Get-InboxRulesByFolders {
    [CmdletBinding()]
    [OutputType([Void], [PSObject[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Mailbox,

        [ValidateNotNullOrEmpty()]
        [String]$DescriptionTimeZone = 'AUS Eastern Standard Time',

        [ValidateNotNullOrEmpty()]
        [String]$DescriptionTimeFormat = 'yyyy/mm/dd',

        [Switch]$ReturnUnlinkedRules,

        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    Test-CommandAvailable -Name Get-Mailbox

    $WriteProgressParams = @{
        Activity = 'Retrieving inbox rules by folders'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox folders' -PercentComplete 1
    $Folders = Get-MailboxFolder -Identity ('{0}:\Inbox' -f $Mailbox) -MailFolderOnly -Recurse | Where-Object DefaultFolderType -NE 'Inbox'
    $Folders | Add-Member -MemberType NoteProperty -Name Rules -Value @()
    $Folders | Add-Member -MemberType ScriptProperty -Name RuleCount -Value { $this.Rules.Count }

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox rules' -PercentComplete 33
    $Rules = Get-InboxRule -DescriptionTimeZone $DescriptionTimeZone -DescriptionTimeFormat $DescriptionTimeFormat
    $Rules | Add-Member -MemberType NoteProperty -Name LinkedToFolder -Value $false

    Write-Progress @WriteProgressParams -Status 'Associating rules to folders' -PercentComplete 67
    foreach ($Folder in $Folders) {
        $FolderName = ($Folder.FolderPath -join ' - ').Substring(8)
        $RegexMatch = '^{0}' -f [Regex]::Escape($FolderName)

        foreach ($Rule in ($Rules | Where-Object LinkedToFolder -EQ $false)) {
            if ($Rule.Name -match $RegexMatch -and $Rule.MoveToFolder -eq $Folder.Name) {
                $Rule.LinkedToFolder = $true
                $Folder.Rules += $Rule
            }
        }
    }

    $UnlinkedRules = $Rules | Where-Object LinkedToFolder -EQ $false
    if ($UnlinkedRules) {
        Write-Warning -Message 'The following rules could not be linked to a folder:'
        foreach ($Rule in ($UnlinkedRules | Sort-Object -Property Name)) {
            Write-Warning -Message $Rule.Name
        }
    }

    Write-Progress @WriteProgressParams -Completed

    if ($ReturnUnlinkedRules) {
        return $UnlinkedRules
    }

    return $Folders
}

# Retrieve a summary of sent & received totals for a mailbox
Function Get-MailboxActivitySummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Mailbox,

        [DateTime]$StartDate,
        [DateTime]$EndDate,

        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    Test-CommandAvailable -Name Get-Mailbox

    if (!$EndDate) {
        $EndDate = Get-Date
    }

    if (!$StartDate) {
        $StartDate = $EndDate.AddDays(-7)
    }

    $WriteProgressParams = @{
        Activity = 'Retrieving mailbox activity summary'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox details' -PercentComplete 1
    $ExoMailbox = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
    $Addresses = $ExoMailbox.EmailAddresses | Where-Object { $_ -match '^smtp:' } | ForEach-Object { $_.Substring(5) }

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox send logs' -PercentComplete 33
    $Sent = Get-MessageTrace -SenderAddress $Addresses -StartDate $StartDate -EndDate $EndDate

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox receive logs' -PercentComplete 67
    $Received = Get-MessageTrace -RecipientAddress $Addresses -StartDate $StartDate -EndDate $EndDate

    Write-Progress @WriteProgressParams -Completed

    $Summary = [PSCustomObject]@{
        Mailbox   = $ExoMailbox.PrimarySmtpAddress
        StartDate = $StartDate.ToString()
        EndDate   = $EndDate.ToString()
        Sent      = ($Sent | Measure-Object).Count
        Received  = ($Received | Measure-Object).Count
    }

    return $Summary
}

#endregion

#region Reporting

# Retrieve a usage summary for an entity
Function Get-Office365EntityUsageSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(ParameterSetName = 'User', Mandatory)]
        [String]$UserPrincipalName,

        [Parameter(ParameterSetName = 'Group', Mandatory)]
        [String]$GroupIdentity
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'This function uses modules incompatible with PowerShell Core.'
    }

    $Type = $PSCmdlet.ParameterSetName.ToLower()

    $Modules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Notes'
        'Microsoft.Graph.Planner'
        'Microsoft.Online.SharePoint.PowerShell'
        'MicrosoftTeams'
    )

    if ($Type -eq 'User') {
        $Modules += 'MSOnline'
    }

    Write-Verbose -Message 'Checking required modules are present ...'
    Test-ModuleAvailable -Name $Modules
    Test-CommandAvailable -Name Get-OrganizationConfig

    if ($Type -eq 'User') {
        Write-Verbose -Message 'Checking Microsoft Online connection ...'
        try {
            $CompanyInfo = Get-MsolCompanyInformation -ErrorAction Stop
        } catch {
            throw $_
        }
    }

    Write-Verbose -Message 'Checking Exchange Online connection ...'
    try {
        $null = Get-OrganizationConfig -ErrorAction Stop
    } catch {
        throw $_
    }

    Write-Verbose -Message 'Checking SharePoint Online connection ...'
    try {
        $null = Get-SPOTenant -ErrorAction Stop
    } catch {
        throw $_
    }

    Write-Verbose -Message 'Checking Microsoft Teams connection ...'
    try {
        $null = Get-TeamsApp -ErrorAction Stop -Verbose:$false
    } catch {
        throw $_
    }

    Write-Verbose -Message 'Connecting to Microsoft Graph API ...'
    try {
        $null = Connect-MgGraph -Scopes Group.Read.All, Notes.Read.All -ErrorAction Stop
    } catch {
        throw $_
    }

    # Base entity
    Write-Verbose -Message ('Retrieving {0} ...' -f $Type)
    if ($Type -eq 'User') {
        try {
            $User = Get-MsolUser -UserPrincipalName $UserPrincipalName -ErrorAction Stop
        } catch {
            throw $_
        }

        $ExoIdentity = $UserPrincipalName
    } else {
        try {
            $Group = Get-UnifiedGroup -Identity $GroupIdentity -IncludeAllProperties -ErrorAction Stop
        } catch {
            throw $_
        }

        $ExoIdentity = $Group.PrimarySmtpAddress
    }

    # Mailbox
    Write-Verbose -Message ('Retrieving {0} mailbox ...' -f $Type)
    try {
        if ($Type -eq 'User') {
            $Mailbox = Get-Mailbox -Identity $ExoIdentity -ErrorAction Stop
        } else {
            $Mailbox = Get-Mailbox -Identity $ExoIdentity -GroupMailbox -ErrorAction Stop
        }
        $Mailbox | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.PrimarySmtpAddress } -Force
    } catch {
        throw $_
    }

    # Mailbox statistics
    Write-Verbose -Message ('Retrieving {0} mailbox statistics ...' -f $Type)
    try {
        $MailboxStatistics = Get-MailboxStatistics -Identity $ExoIdentity -ErrorAction Stop
        $MailboxStatistics | Add-Member -MemberType ScriptMethod -Name ToString -Value { '{0} items / {1}' -f $this.ItemCount, $this.TotalItemSize } -Force
    } catch {
        throw $_
    }

    # Calendar
    Write-Verbose -Message ('Retrieving {0} calendar ...' -f $Type)
    try {
        $Calendar = Get-MailboxFolderStatistics -Identity $ExoIdentity -FolderScope Calendar -ErrorAction Stop | Where-Object FolderType -EQ 'Calendar'
        $Calendar | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.VisibleItemsInFolder } -Force
    } catch {
        throw $_
    }

    # Groups
    if ($Type -eq 'User') {
        Write-Verbose -Message 'Retrieving user group ownership ...'
        try {
            $ExoRecipientFilter = 'ManagedBy -eq "{0}"' -f $Mailbox.DistinguishedName
            $Groups = Get-Recipient -Filter $ExoRecipientFilter -RecipientTypeDetails GroupMailbox -ErrorAction Stop
        } catch {
            throw $_
        }
    }

    # Site
    Write-Verbose -Message ('Retrieving {0} site ...' -f $Type)
    try {
        if ($Type -eq 'User') {
            $TenantName = $CompanyInfo.InitialDomain.Split('.')[0]
            $SPOSiteFilter = 'Url -like "https://{0}-my.sharepoint.com/personal/*" -and Owner -eq "{1}"' -f $TenantName, $UserPrincipalName
            $PersonalSite = Get-SPOSite -Filter $SPOSiteFilter -IncludePersonalSite:$true -ErrorAction Stop
            $Site = Get-SPOSite -Identity $PersonalSite.Url -Detailed -ErrorAction Stop
        } else {
            $Site = Get-SPOSite -Identity $Group.SharePointSiteUrl -Detailed -ErrorAction Stop
        }
        $Site | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.StorageUsageCurrent } -Force
    } catch {
        throw $_
    }

    # Teams
    if ($Type -eq 'Group') {
        Write-Verbose -Message 'Retrieving group teams ...'
        if ($Group.ResourceProvisioningOptions -contains 'Team') {
            try {
                $Teams = @(Get-Team -GroupId $Group.ExternalDirectoryObjectId -ErrorAction Stop)
            } catch {
                throw $_
            }
        }
    }

    # OneNote
    # https://docs.microsoft.com/en-us/graph/api/resources/onenote-api-overview?view=graph-rest-1.0
    Write-Verbose -Message ('Retrieving {0} notebooks ...' -f $Type)
    try {
        if ($Type -eq 'User') {
            $Notebooks = @(Get-MgUserOnenoteNotebook -UserId $User.UserPrincipalName -ErrorAction Stop)
            $NotebookSections = @(Get-MgUserOnenoteSection -UserId $User.UserPrincipalName -ErrorAction Stop)
            $NotebookPages = @(Get-MgUserOnenotePage -UserId $User.UserPrincipalName -ErrorAction Stop)
        } else {
            $Notebooks = @(Get-MgGroupOnenoteNotebook -GroupId $Group.ExternalDirectoryObjectId -ErrorAction Stop)
            $NotebookSections = @(Get-MgGroupOnenoteSection -GroupId $Group.ExternalDirectoryObjectId -ErrorAction Stop)
            $NotebookPages = @(Get-MgGroupOnenotePage -GroupId $Group.ExternalDirectoryObjectId -ErrorAction Stop)
        }
    } catch {
        Write-Warning -Message $_.ErrorDetails
    }

    # Planner
    # https://docs.microsoft.com/en-us/graph/api/resources/planner-overview?view=graph-rest-1.0
    if ($Type -eq 'Group') {
        Write-Verbose -Message ('Retrieving {0} plans ...' -f $Type)
        try {
            $Plans = @(Get-MgGroupPlannerPlan -GroupId $Group.ExternalDirectoryObjectId -ErrorAction Stop)
        } catch {
            Write-Warning -Message $_.ErrorDetails
        }
    }

    switch ($Type) {
        'User' {
            $Summary = [PSCustomObject]@{
                User              = $User
                Mailbox           = $Mailbox
                MailboxStatistics = $MailboxStatistics
                Calendar          = $Calendar
                Groups            = $Groups
                Site              = $Site
                Notebooks         = $Notebooks
                NotebookSections  = $NotebookSections
                NotebookPages     = $NotebookPages
            }
            $Summary.PSObject.TypeNames.Insert(0, 'Microsoft.Office365.EntityUsageSummary.User')
        }

        'Group' {
            $Summary = [PSCustomObject]@{
                Group             = $Group
                Mailbox           = $Mailbox
                MailboxStatistics = $MailboxStatistics
                Calendar          = $Calendar
                Site              = $Site
                Teams             = $Teams
                Notebooks         = $Notebooks
                NotebookSections  = $NotebookSections
                NotebookPages     = $NotebookPages
                Plans             = $Plans
            }
            $Summary.PSObject.TypeNames.Insert(0, 'Microsoft.Office365.EntityUsageSummary.Group')
        }
    }

    return $Summary
}

# Retrieve a matrix of user licenses
Function Get-Office365UserLicensingMatrix {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param()

    Test-CommandAvailable -Name Get-MsolUser

    $Users = Get-MsolUser -All
    $Licenses = $Users.Licenses.AccountSkuId | Sort-Object -Unique | ForEach-Object { $_.Split(':')[1] }

    $Matrix = [Collections.Generic.List[PSCustomObject]]::new()
    $MatrixEntry = [PSCustomObject]@{ UserPrincipalName = '' }
    foreach ($License in $Licenses) {
        $MatrixEntry | Add-Member -MemberType NoteProperty -Name $License -Value $false
    }

    foreach ($User in $Users) {
        if (!$User.isLicensed) {
            continue
        }

        $UserLicensing = $MatrixEntry.PSObject.Copy()
        $UserLicensing.UserPrincipalName = $User.UserPrincipalName
        foreach ($License in $User.Licenses) {
            $LicenseName = $License.AccountSkuId.Split(':')[1]
            $UserLicensing.$LicenseName = $true
        }

        $Matrix.Add($UserLicensing)
    }

    return $Matrix.ToArray()
}

# Retrieve a security report for all users
# Improved version of: https://github.com/OfficeDev/O365-InvestigationTooling/blob/master/DumpDelegatesandForwardingRules.ps1
Function Get-Office365UserSecurityReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(1, 90)]
        [Int]$AccountInactiveDays = 30
    )

    Test-CommandAvailable -Name Get-Mailbox, Get-MsolUser

    $MailboxAuditing = [Collections.Generic.List[PSCustomObject]]::new()
    $MailboxCalendar = [Collections.Generic.List[Object]]::new()
    $MailboxDelegates = [Collections.Generic.List[Object]]::new()
    $MailboxForwarding = [Collections.Generic.List[PSCustomObject]]::new()
    $MailboxForwardingRules = [Collections.Generic.List[Object]]::new()
    $MailboxSendAs = [Collections.Generic.List[Object]]::new()
    $MailboxSendOnBehalf = [Collections.Generic.List[PSCustomObject]]::new()

    Write-Verbose -Message 'Retrieving all enabled users ...'
    $Users = Get-MsolUser -All -EnabledFilter EnabledOnly -ErrorAction Stop |
        Where-Object UserType -NE 'Guest' |
        Sort-Object -Property UserPrincipalName |
        ForEach-Object {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name IsActive -Value $false
            Add-Member -InputObject $_ -MemberType ScriptProperty -Name IsFederated -Value { if ($null -ne $this.ImmutableId) { $true } else { $false } }
            Add-Member -InputObject $_ -MemberType ScriptProperty -Name StrongAuthenticationState -Value { $this.StrongAuthenticationRequirements.State }
            $_.PSObject.TypeNames.Insert(0, 'Microsoft.Online.Administration.User.Security')
            $_
        }

    Write-Verbose -Message ('Retrieving user logins over last {0} days ...' -f $AccountInactiveDays)
    $LoginsStartDate = (Get-Date).AddDays(-$AccountInactiveDays).ToString('MM/dd/yyyy')
    $LoginsEndDate = (Get-Date).ToString('MM/dd/yyyy')
    $Logins = Search-UnifiedAuditLog -Operations UserLoggedIn -StartDate $LoginsStartDate -EndDate $LoginsEndDate -ResultSize 5000

    if ($Logins.Count -eq 5000) {
        Write-Warning -Message 'User logins audit log search returned maximum number of results.'
    }

    $ActiveUsers = @($Logins.UserIds | Sort-Object -Unique)
    foreach ($User in $Users) {
        if ($User.UserPrincipalName -in $ActiveUsers) {
            $User.IsActive = $true
        }
    }

    Write-Verbose -Message 'Retrieving all mailboxes ...'
    $Mailboxes = Get-Mailbox -ResultSize Unlimited

    foreach ($Mailbox in $Mailboxes) {
        Write-Verbose -Message ('Inspecting mailbox: {0}' -f $Mailbox.UserPrincipalName)

        $Auditing = [PSCustomObject]@{
            UserPrincipalName = $Mailbox.UserPrincipalName
            AuditEnabled      = $Mailbox.AuditEnabled
            AuditLogAgeLimit  = $Mailbox.AuditLogAgeLimit
            AuditOwner        = $Mailbox.AuditOwner
            AuditDelegate     = $Mailbox.AuditDelegate
            AuditAdmin        = $Mailbox.AuditAdmin
        }
        $MailboxAuditing.Add($Auditing)

        if ($Mailbox.ForwardingSmtpAddress) {
            $Forwarding = [PSCustomObject]@{
                UserPrincipalName          = $Mailbox.UserPrincipalName
                ForwardingAddress          = $Mailbox.ForwardingAddress
                ForwardingSmtpAddress      = $Mailbox.ForwardingSmtpAddress
                DeliverToMailboxAndForward = $Mailbox.DeliverToMailboxAndForward
            }
            $MailboxForwarding.Add($Forwarding)
        }

        if ($Mailbox.GrantSendOnBehalfTo) {
            $SendOnBehalf = [PSCustomObject]@{
                UserPrincipalName                 = $Mailbox.UserPrincipalName
                GrantSendOnBehalfTo               = $Mailbox.GrantSendOnBehalfTo
                MessageCopyForSendOnBehalfEnabled = $Mailbox.MessageCopyForSendOnBehalfEnabled
            }
            $MailboxSendOnBehalf.Add($SendOnBehalf)
        }

        Get-RecipientPermission -Identity $Mailbox.UserPrincipalName |
            Where-Object Trustee -NE 'NT AUTHORITY\SELF' |
            ForEach-Object {
                $_.PSObject.TypeNames.Insert(0, 'Deserialized.Microsoft.Exchange.Data.Directory.Permission.RecipientPermission.SendAs')
                $MailboxSendAs.Add($_)
            }

        Get-MailboxPermission -Identity $Mailbox.UserPrincipalName |
            Where-Object {
                $_.IsInherited -ne 'True' -and
                $_.User -ne 'NT AUTHORITY\SELF'
            } | ForEach-Object {
                $_.PSObject.TypeNames.Insert(0, 'Deserialized.Microsoft.Exchange.Management.RecipientTasks.MailboxAcePresentationObject.Delegates')
                $MailboxDelegates.Add($_)
            }

        $CalendarFolder = Get-MailboxFolderStatistics -Identity $Mailbox.UserPrincipalName -FolderScope Calendar | Where-Object FolderType -EQ 'Calendar'
        Get-MailboxFolderPermission -Identity ('{0}:\{1}' -f $Mailbox.UserPrincipalName, $CalendarFolder.Name) |
            Where-Object {
                !($_.User.UserType.Value -eq 'Default' -and $_.AccessRights -eq 'AvailabilityOnly') -and
                !($_.User.UserType.Value -eq 'Anonymous' -and $_.AccessRights -eq 'None')
            } | ForEach-Object {
                $_.PSObject.TypeNames.Insert(0, 'Deserialized.Microsoft.Exchange.Management.StoreTasks.MailboxFolderPermission.Calendar')
                $MailboxCalendar.Add($_)
            }

        Get-InboxRule -Mailbox $Mailbox.UserPrincipalname |
            Where-Object {
                $null -ne $_.ForwardTo -or
                $null -ne $_.ForwardAsAttachmentTo -or
                $null -ne $_.RedirectTo
            } | ForEach-Object {
                $_.PSObject.TypeNames.Insert(0, 'Deserialized.Microsoft.Exchange.Management.Common.InboxRule.Forwarding')
                $MailboxForwardingRules.Add($_)
            }
    }

    $Results = [PSCustomObject]@{
        Users                  = $Users
        MailboxAuditing        = $MailboxAuditing.ToArray()
        MailboxCalendar        = $MailboxCalendar.ToArray()
        MailboxDelegates       = $MailboxDelegates.ToArray()
        MailboxForwarding      = $MailboxForwarding.ToArray()
        MailboxForwardingRules = $MailboxForwardingRules.ToArray()
        MailboxSendAs          = $MailboxSendAs.ToArray()
        MailboxSendOnBehalf    = $MailboxSendOnBehalf.ToArray()
    }

    return $Results
}

# Retrieve a report on unified groups with owner & member details
Function Get-UnifiedGroupReport {
    [CmdletBinding()]
    [OutputType([Void], [PSObject[]])]
    Param(
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$Groups
    )

    Test-CommandAvailable -Name Get-UnifiedGroup

    $WriteProgressParams = @{
        Activity = 'Retrieving Unified Group report'
    }

    if (!$Groups) {
        Write-Progress @WriteProgressParams -Status 'Retrieving Office 365 groups' -PercentComplete 1
        $Groups = Get-UnifiedGroup
    }

    $GroupsDone = 0
    foreach ($Group in $Groups) {
        Write-Progress @WriteProgressParams -Status ('Retrieving group: {0}' -f $Group.Identity) -PercentComplete ($GroupsDone / $Groups.Count * 90 + 10)

        Write-Progress @WriteProgressParams -CurrentOperation 'Retrieving owners'
        $Owners = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Owners
        if ($Owners) {
            $AllOwners = ($Owners | Sort-Object) -join ', '
            Add-Member -InputObject $Group -MemberType NoteProperty -Name Owners -Value $AllOwners -Force
        }

        Write-Progress @WriteProgressParams -CurrentOperation 'Retrieving members'
        $Members = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Members
        if ($Members) {
            $AllMembers = ($Members | Sort-Object) -join ', '
            Add-Member -InputObject $Group -MemberType NoteProperty -Name Members -Value $AllMembers -Force
        }

        $GroupsDone++
    }

    Write-Progress @WriteProgressParams -Completed

    return $Groups
}

#endregion

#region Security & Compliance

# Compare Security & Compliance policies
Function Compare-ProtectionAlert {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[][]])]
    Param(
        [Parameter(Mandatory)]
        [PSObject[]]$ReferenceObject,

        [Parameter(Mandatory)]
        [PSObject[]]$DifferenceObject
    )

    $IgnoredProperties = @(
        'AlertOverrideChangedUtc'
        'RunspaceId'
    )

    $Results = [Collections.Generic.List[PSCustomObject]]::new()

    foreach ($RefAlert in ($ReferenceObject | Sort-Object -Property Name)) {
        $DiffAlert = $DifferenceObject | Where-Object Name -EQ $RefAlert.Name
        if (!$DiffAlert) {
            Write-Warning -Message ('[ID: {0}] Reference alert with no associated difference alert (Ref Name: {1}).' -f $RefAlert.ImmutableId, $RefAlert.Name)
            continue
        }

        $Diff = Compare-ObjectProperties -ReferenceObject $RefAlert -DifferenceObject $DiffAlert -IgnoredProperties $IgnoredProperties
        if ($Diff) {
            $AlertName = [PSCustomObject]@{
                PropertyName = 'AlertName'
                RefValue     = $RefAlert.Name
                DiffValue    = $DiffAlert.Name
            }

            $ImmutableId = [PSCustomObject]@{
                PropertyName = 'ImmutableId'
                RefValue     = $RefAlert.ImmutableId
                DiffValue    = $DiffAlert.ImmutableId
            }

            $Result = @($AlertName, $ImmutableId, $Diff)
            $Results.Add($Result)
        }
    }

    foreach ($DiffAlert in ($DifferenceObject | Sort-Object -Property Name)) {
        $RefAlert = $ReferenceObject | Where-Object Name -EQ $DiffAlert.Name
        if (!$RefAlert) {
            Write-Warning -Message ('[ID: {0}] Difference alert with no associated reference alert (Ref Name: {1}).' -f $DiffAlert.ImmutableId, $DiffAlert.Name)
            continue
        }
    }

    return $Results.ToArray()
}

# Extract email addresses and names from Content Search results
Function Import-ContentSearchResults {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(ParameterSetName = 'File', Mandatory)]
        [String[]]$CsvFile,

        [Parameter(ParameterSetName = 'File')]
        [Char]$CsvDelimiter = ',',

        [Parameter(ParameterSetName = 'Data', Mandatory)]
        [Object[]]$CsvData,

        [ValidateSet('From', 'To', 'Cc', 'Bcc')]
        [String[]]$ImportFields = @('From', 'To', 'Cc', 'Bcc'),

        [String[]]$IgnoredEntries = 'O=EXCHANGELABS',
        [String[]]$IgnoredDomains,

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]$EntryLimit
    )

    Begin {
        $Contacts = @{}
        $Statistics = [Ordered]@{}

        $DataFields = @()
        $ImportFieldsLookup = @{
            From = 'Sender or Created by'
            To   = 'Recipients in To line'
            Cc   = 'Recipients in Cc line'
            Bcc  = 'Recipients in Bcc line'
        }

        foreach ($ImportField in $ImportFields) {
            $DataFields += $ImportFieldsLookup[$ImportField]

            $Statistics[$ImportField] = [Ordered]@{
                Empty            = 0
                EntryIgnored     = 0
                AddressMalformed = 0
                DomainIgnored    = 0
                NameMissing      = 0
            }
        }

        $ImportContentSearchResultsEntryParams = @{
            Statistics = $Statistics
        }

        if ($IgnoredEntries) {
            $ImportContentSearchResultsEntryParams['IgnoredEntries'] = $IgnoredEntries
        }

        if ($IgnoredDomains) {
            $EscapedDomains = @()

            foreach ($Domain in $IgnoredDomains) {
                $EscapedDomains += [Regex]::Escape($Domain.ToLower())
            }

            $IgnoredDomainsRegex = '@({0})$' -f ($EscapedDomains -join '|')
            $ImportContentSearchResultsEntryParams['IgnoredDomains'] = $IgnoredDomainsRegex
            Write-Verbose -Message ('Ignored domains regex: {0}' -f $IgnoredDomainsRegex)
        }
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'File') {
            try {
                $Data = Import-Csv -LiteralPath $CsvFile -Delimiter $CsvDelimiter -ErrorAction Stop
            } catch {
                throw $_
            }
        } else {
            $Data = $CsvData
        }

        Write-Verbose -ForegroundColor Green ('Loaded {0} entries for processing.' -f $Data.Count)

        $EntryNumber = 0
        foreach ($Entry in $Data) {
            $DataFieldIndex = 0
            $EntryNumber++

            foreach ($ImportField in $ImportFields) {
                $DataField = $DataFields[$DataFieldIndex]
                $DataFieldIndex++

                $FieldEntry = $Entry.$DataField
                $ItemId = $Entry.'Item Identity'
                if (!$FieldEntry) {
                    $Statistics[$ImportField]['Empty']++
                    Write-Debug -Message ('[{0}] Skipping empty "{1}" field.' -f $ItemId, $DataField)
                    continue
                }

                foreach ($Contact in (Import-ContentSearchResultsEntry -Field $ImportField -Entry $FieldEntry -ItemId $ItemId @ImportContentSearchResultsEntryParams)) {
                    $Address = $Contact.Address
                    $CandidateName = $Contact.Name

                    # If the contact doesn't exist then add it
                    if (!$Contacts.ContainsKey($Address)) {
                        $Contacts[$Address] = $CandidateName
                        continue
                    }

                    $CurrentName = $Contacts[$Address]

                    # Bail-out early when any of:
                    # - The candidate name is blank or whitespace
                    # - The candidate name is identical to the current name
                    if ([String]::IsNullOrWhiteSpace($CandidateName) -or
                        $CandidateName -ceq $CurrentName) {
                        continue
                    }

                    # Use the candidate name if it's longer than the current
                    # name. If it's shorter then we've already got the best
                    # contact name.
                    if ($CandidateName.Length -ne $CurrentName.Length) {
                        if ($CandidateName.Length -gt $CurrentName.Length) {
                            Write-Verbose -Message ('[{0}] Updating name for {1} to: {2}' -f $ItemId, $Address, $CandidateName)
                            $Contacts[$Address] = $CandidateName
                        }
                        continue
                    }

                    # The current contact name and candidate name are:
                    # - The same length
                    # - Differ other than by case
                    #
                    # It's unclear what to do here so print out the options.
                    if ($CandidateName.ToLower() -ne $CurrentName.ToLower()) {
                        Write-Warning -Message ('[{0}] Mismatched name in "{1}" entry for email address: {2}' -f $ItemId, $DataField, $Address)
                        Write-Warning -Message (' {0}  Current:   {1}' -f ''.PadLeft($ItemId.Length), $CurrentName)
                        Write-Warning -Message (' {0}  Candidate: {1}' -f ''.PadLeft($ItemId.Length), $CandidateName)
                    }
                }
            }

            if (($EntryNumber % 1000) -eq 0) {
                Write-Verbose -ForegroundColor Green ('Processed {0} entries ...' -f $EntryNumber)
            }

            if ($EntryLimit -and $EntryNumber -eq $EntryLimit) {
                break
            }
        }
    }

    End {
        $Results = @{
            Contacts   = $Contacts
            Statistics = $Statistics
        }

        return $Results
    }
}

# Extract email addresses and names from a Content Search results entry
Function Import-ContentSearchResultsEntry {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Field,

        [Parameter(Mandatory)]
        [String]$Entry,

        [Parameter(Mandatory)]
        [String]$ItemId,

        [Parameter(Mandatory)]
        [Hashtable]$Statistics,

        [String[]]$IgnoredEntries,
        [Regex]$IgnoredDomains
    )

    # Split a field into comma separated elements
    #
    # Each element should consist of (in order):
    # - An optional name
    # - An email address
    #
    # This gets messy fast as the formatting of is extremely variable. The only
    # guarantee is that distinct elements are comma-separated. However, there
    # may be commas within the name component (which itself is optional).
    $ElementRegex = '^(\S+\s+)*?\S+?@\S+?\.\S+(?=, )'

    # Check if an element contains a valid SMTP address
    $AddressRegex = '(\S+?@\S+?\.\S+)$'

    # Check if an element contains a name which is *not* the SMTP address
    $NameRegex = '^((\S+\s+)*?)(?=(\s*\S+?@\S+?\.\S+)+)'

    $Results = [Collections.Generic.List[PSCustomObject]]::new()
    $Elements = [Collections.Generic.List[String]]::new()
    $Entry = $Entry.Replace('"', [String]::Empty)

    do {
        if ($Entry -match $ElementRegex) {
            $Elements.Add($Matches[0])
            $Entry = $Entry.Substring($Matches[0].Length + 2)
        } else {
            $Elements.Add($Entry)
            break
        }
    } while ($true)

    foreach ($Element in $Elements) {
        if ($Element -notmatch $AddressRegex) {
            if ($Element -eq ';' -or $Element -in $IgnoredEntries) {
                $Statistics[$Field]['EntryIgnored']++
                Write-Debug -Message ('[{0}] Skipping ignored "{1}" entry: {2}' -f $ItemId, $DataField, $Element)
            } else {
                $Statistics[$Field]['AddressMalformed']++
                Write-Warning -Message ('[{0}] Unable to extract email address from "{1}" entry: {2}' -f $ItemId, $DataField, $Element)
            }
            continue
        }

        $Result = [PSCustomObject]@{
            Address = $Matches[0].Trim("<>'.").ToLower()
            Name    = [String]::Empty
        }

        if ($IgnoredDomains) {
            if ($Result.Address -match $IgnoredDomains) {
                $Statistics[$Field]['DomainIgnored']++
                Write-Debug -Message ('[{0}] Skipping ignored domain in "{1}" entry: {2}' -f $ItemId, $DataField, $Result.Address)
                continue
            }
        }

        if ($Element -match $NameRegex -and $Matches[0].Length -ne 0) {
            $Name = $Matches[0]
            while ($Name -match "[\s|']$") {
                $Name = $Name.Trim().Trim("'")
            }
            $Result.Name = $Name
        } else {
            $Statistics[$Field]['NameMissing']++
            Write-Debug -Message ('[{0}] Unable to extract name from "{1}" entry with email address: {2}' -f $ItemId, $DataField, $Result.Address)
        }

        $Results.Add($Result)
    }

    return $Results.ToArray()
}

#endregion

#region Service connection helpers

# Helper function to connect to all Office 365 services
Function Connect-Office365Services {
    [CmdletBinding(DefaultParameterSetName = 'MFA')]
    [OutputType([Void])]
    Param(
        [Parameter(ParameterSetName = 'MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName = 'Standard', Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential,

        [Parameter(Mandatory)]
        [String]$TenantName
    )

    $DefaultParams = @{}
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        if ($MfaUsername) {
            $DefaultParams['MfaUsername'] = $MfaUsername
        }
    } else {
        $DefaultParams['Credential'] = $Credential
    }

    Connect-ExchangeOnline @DefaultParams
    Connect-SecurityAndComplianceCenter @DefaultParams

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-SharePointOnline -TenantName $TenantName
        $null = Connect-MicrosoftTeams
        Connect-CentralizedDeployment
    } else {
        Connect-SharePointOnline @DefaultParams -TenantName $TenantName
        $null = Connect-MicrosoftTeams @DefaultParams
        Connect-CentralizedDeployment @DefaultParams
    }
}

# Helper function to connect to Exchange Online
Function Connect-ExchangeOnline {
    [CmdletBinding(DefaultParameterSetName = 'MFA')]
    [OutputType([Void])]
    Param(
        [Parameter(ParameterSetName = 'MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName = 'Standard', Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    try {
        Test-ModuleAvailable -Name ExchangeOnlineManagement
        $ExoModuleVersion = 2
    } catch {
        Write-Warning -Message 'ExchangeOnlineManagement v2 module is not available. Falling back to v1 ...'
        $ExoModuleVersion = 1
    }

    if ($PSVersionTable.PSEdition -eq 'Core') {
        if ($ExoModuleVersion -eq 1) {
            throw 'ExchangeOnlineManagement v1 module is incompatible with PowerShell Core.'
        }

        $ExoModuleMinVersion = [Version]::new(2, 0, 4)
        $ExoModuleCurrentVersion = Get-Module -Name ExchangeOnlineManagement -ListAvailable -Verbose:$false | Select-Object -First 1 -ExpandProperty Version
        if ($ExoModuleCurrentVersion -lt $ExoModuleMinVersion) {
            throw 'ExchangeOnlineManagement under PowerShell Core requires v{0} or newer.' -f $ExoModuleMinVersion
        }
    }

    if ($ExoModuleVersion -eq 1 -and $PSCmdlet.ParameterSetName -eq 'MFA') {
        Import-ExoPowershellModule
    }

    Write-Host -ForegroundColor Green 'Connecting to Exchange Online ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        $ConnectParams = @{}
        if ($MfaUsername) {
            $ConnectParams['UserPrincipalName'] = $MfaUsername
        }

        if ($ExoModuleVersion -eq 2) {
            ExchangeOnlineManagement\Connect-ExchangeOnline @ConnectParams -ShowBanner:$false
        } else {
            Connect-EXOPSSession @ConnectParams
        }
    } else {
        if ($ExoModuleVersion -eq 2) {
            ExchangeOnlineManagement\Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
        } else {
            $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
            Import-PSSession -Session $ExchangeOnline -DisableNameChecking
        }
    }
}

# Helper function to connect to Centralized Deployment
Function Connect-CentralizedDeployment {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'O365CentralizedAddInDeployment module is incompatible with PowerShell Core.'
    }

    Test-ModuleAvailable -Name O365CentralizedAddInDeployment

    Write-Host -ForegroundColor Green 'Connecting to Office 365 Centralized Deployment ...'
    Connect-OrganizationAddInService @PSBoundParameters
}

# Helper function to connect to Microsoft Teams
Function Connect-MicrosoftTeams {
    [CmdletBinding()]
    [OutputType('Microsoft.TeamsCmdlets.Powershell.Connect.Models.PSAzureContext')]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'MicrosoftTeams module is incompatible with PowerShell Core.'
    }

    Test-ModuleAvailable -Name MicrosoftTeams

    Write-Host -ForegroundColor Green 'Connecting to Microsoft Teams ...'
    MicrosoftTeams\Connect-MicrosoftTeams @PSBoundParameters
}

# Helper function to connect to Security & Compliance Center
Function Connect-SecurityAndComplianceCenter {
    [CmdletBinding(DefaultParameterSetName = 'MFA')]
    [OutputType([Void])]
    Param(
        [Parameter(ParameterSetName = 'MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName = 'Standard', Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    try {
        Test-ModuleAvailable -Name ExchangeOnlineManagement
        $ExoModuleVersion = 2
    } catch {
        if ($PSCmdlet.ParameterSetName -eq 'MFA') {
            throw 'ExchangeOnlineManagement v2 module is required to connect using MFA.'
        }

        Write-Warning -Message 'ExchangeOnlineManagement v2 module is not available. Falling back to v1 ...'
        $ExoModuleVersion = 1
    }

    if ($PSVersionTable.PSEdition -eq 'Core') {
        if ($ExoModuleVersion -eq 1) {
            throw 'ExchangeOnlineManagement v1 module is incompatible with PowerShell Core.'
        }

        $ExoModuleMinVersion = [Version]::new(2, 0, 4)
        $ExoModuleCurrentVersion = Get-Module -Name ExchangeOnlineManagement -ListAvailable -Verbose:$false | Select-Object -First 1 -ExpandProperty Version
        if ($ExoModuleCurrentVersion -lt $ExoModuleMinVersion) {
            throw 'ExchangeOnlineManagement under PowerShell Core requires v{0} or newer.' -f $ExoModuleMinVersion
        }
    }

    if ($ExoModuleVersion -eq 1 -and $PSCmdlet.ParameterSetName -eq 'MFA') {
        Import-ExoPowershellModule
    }

    Write-Host -ForegroundColor Green 'Connecting to Security and Compliance Center ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        if ($MfaUsername) {
            Connect-IPPSSession -UserPrincipalName $MfaUsername
        } else {
            Connect-IPPSSession
        }
    } else {
        if ($ExoModuleVersion -eq 2) {
            Connect-IPPSSession -Credential $Credential
        } else {
            $SCC = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://ps.compliance.protection.outlook.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
            Import-PSSession -Session $SCC -DisableNameChecking
        }
    }
}

# Helper function to connect to SharePoint Online
Function Connect-SharePointOnline {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$TenantName,

        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'Microsoft.Online.SharePoint.PowerShell module is incompatible with PowerShell Core.'
    }

    Test-ModuleAvailable -Name Microsoft.Online.SharePoint.PowerShell

    $ConnectParams = @{
        Url = 'https://{0}-admin.sharepoint.com' -f $TenantName
    }

    if ($Credential) {
        $ConnectParams['Credential'] = $Credential
    }

    Write-Host -ForegroundColor Green 'Connecting to SharePoint Online ...'
    Connect-SPOService @ConnectParams
}

# Helper function to import the weird Exchange Online v1 module
Function Import-ExoPowershellModule {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if (Get-Command -Name Connect-EXOPSSession -ErrorAction Ignore) {
        return
    }

    $ClickOnceAppsPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Apps\2.0'
    $ExoPowerShellManifest = Get-ChildItem -LiteralPath $ClickOnceAppsPath -Recurse | Where-Object Name -EQ 'Microsoft.Exchange.Management.ExoPowershellModule.manifest' | Sort-Object -Property LastWriteTime | Select-Object -Last 1
    if (!$ExoPowerShellManifest) {
        throw 'Required module not available: Microsoft.Exchange.Management.ExoPowershellModule'
    }

    Write-Verbose -Message 'Importing Microsoft.Exchange.Management.ExoPowershellModule ...'
    $ExoPowerShellScript = Join-Path -Path $ExoPowerShellManifest.Directory -ChildPath 'CreateExoPSSession.ps1'

    # Sourcing the script rudely changes the current working directory
    $CurrentPath = Get-Location
    . $ExoPowerShellScript
    Set-Location -LiteralPath $CurrentPath

    # Change the scope of imported functions to be global (better approach?)
    $Functions = 'Connect-EXOPSSession', 'Connect-IPPSSession', 'Test-Uri'
    foreach ($Function in $Functions) {
        $null = New-Item -Path Function: -Name Global:$Function -Value (Get-Content -LiteralPath Function:\$Function)
    }
}

#endregion

Complete-DotFilesSection
