$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Microsoft 365'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Microsoft 365.format.ps1xml'))

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

    Test-CommandAvailable -Name 'Get-Mailbox'

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

    Test-CommandAvailable -Name 'Get-Mailbox'

    $WriteProgressParams = @{
        Activity = 'Retrieving inbox rules by folders'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox folders' -PercentComplete 1
    $Folders = Get-MailboxFolder -Identity ('{0}:\Inbox' -f $Mailbox) -MailFolderOnly -Recurse | Where-Object DefaultFolderType -NE 'Inbox'
    $Folders | Add-Member -MemberType NoteProperty -Name 'Rules' -Value @()
    $Folders | Add-Member -MemberType ScriptProperty -Name 'RuleCount' -Value { $this.Rules.Count }

    Write-Progress @WriteProgressParams -Status 'Retrieving mailbox rules' -PercentComplete 33
    $Rules = Get-InboxRule -DescriptionTimeZone $DescriptionTimeZone -DescriptionTimeFormat $DescriptionTimeFormat
    $Rules | Add-Member -MemberType NoteProperty -Name 'LinkedToFolder' -Value $false

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
        foreach ($Rule in ($UnlinkedRules | Sort-Object -Property 'Name')) {
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

    Test-CommandAvailable -Name 'Get-Mailbox', 'Get-MessageTrace'

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

# Retrieve a usage summary for a M365 user or group
Function Get-M365UsageSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(ParameterSetName = 'User', Mandatory)]
        [String]$UserPrincipalName,

        [Parameter(ParameterSetName = 'Group', Mandatory)]
        [String]$GroupIdentity
    )

    $RequiredModules = @(
        'ExchangeOnlineManagement'
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Notes'
        'Microsoft.Graph.Planner'
        'Microsoft.Online.SharePoint.PowerShell'
        'MicrosoftTeams'
    )

    if ($PSCmdlet.ParameterSetName -eq 'User') {
        $RequiredModules += @(
            'Microsoft.Graph.Identity.DirectoryManagement'
            'Microsoft.Graph.Users'
        )
    }

    Write-Verbose -Message 'Checking required modules are present ...'
    Test-ModuleAvailable -Name $RequiredModules

    try {
        Write-Verbose -Message 'Connecting to Microsoft Graph API ...'
        $null = Connect-MgGraph -Scopes 'Group.Read.All', 'Notes.Read.All' -ErrorAction 'Stop'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    try {
        Write-Verbose -Message 'Checking Exchange Online connection ...'
        $null = Get-OrganizationConfig -ErrorAction 'Stop'
    } catch {
        switch ($PSItem.FullyQualifiedErrorId) {
            'CommandNotFoundException' {
                $ErrMsg = 'Expected command not found: Get-OrganizationConfig. Have you run Connect-ExchangeOnline?'
                $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
                $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'CommandNotFound', $ErrCat, $null)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Default { $PSCmdlet.ThrowTerminatingError($PSItem) }
        }
    }

    try {
        Write-Verbose -Message 'Checking SharePoint Online connection ...'

        if ($PSVersionTable.PSEdition -eq 'Core') {
            Write-Warning -Message 'Microsoft.Online.SharePoint.PowerShell is only supported under Windows PowerShell.'
            Import-Module -Name 'Microsoft.Online.SharePoint.PowerShell' -DisableNameChecking -ErrorAction 'Stop' -Verbose:$false
        }

        $null = Get-SPOTenant -ErrorAction 'Stop'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    try {
        Write-Verbose -Message 'Checking Microsoft Teams connection ...'
        $null = Get-TeamsApp -ErrorAction 'Stop' -Verbose:$false
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    switch ($PSCmdlet.ParameterSetName) {
        'User' {
            $Summary = [PSCustomObject]@{
                User              = $null
                Mailbox           = $null
                MailboxStatistics = $null
                Calendar          = $null
                Groups            = $null
                OneDrive          = $null
                Notebooks         = $null
                NotebookSections  = $null
                NotebookPages     = $null
            }
            $Summary.PSObject.TypeNames.Insert(0, 'Microsoft.M365.UsageSummary.User')
        }

        'Group' {
            $Summary = [PSCustomObject]@{
                Group             = $null
                Mailbox           = $null
                MailboxStatistics = $null
                Calendar          = $null
                Site              = $null
                Teams             = $null
                Notebooks         = $null
                NotebookSections  = $null
                NotebookPages     = $null
                Plans             = $null
            }
            $Summary.PSObject.TypeNames.Insert(0, 'Microsoft.M365.UsageSummary.Group')
        }
    }

    # User / Group
    try {
        Write-Verbose -Message "Retrieving $($PSCmdlet.ParameterSetName.ToLower()) information ..."
        switch ($PSCmdlet.ParameterSetName) {
            'User' {
                $Summary.User = Get-MgUser -UserId $UserPrincipalName -ErrorAction 'Stop'
                $ExoIdentity = $Summary.User.UserPrincipalName
            }

            'Group' {
                $Summary.Group = Get-UnifiedGroup -Identity $GroupIdentity -IncludeAllProperties -ErrorAction 'Stop'
                $ExoIdentity = $Summary.Group.PrimarySmtpAddress
            }
        }
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    # Mailbox
    try {
        Write-Verbose -Message "Retrieving $($PSCmdlet.ParameterSetName.ToLower()) mailbox ..."
        switch ($PSCmdlet.ParameterSetName) {
            'User' { $Summary.Mailbox = Get-Mailbox -Identity $ExoIdentity -ErrorAction 'Stop' }
            'Group' { $Summary.Mailbox = Get-Mailbox -Identity $ExoIdentity -GroupMailbox -ErrorAction 'Stop' }
        }

        $Summary.Mailbox | Add-Member -MemberType 'ScriptMethod' -Name 'ToString' -Value { $this.PrimarySmtpAddress } -Force
    } catch {
        Write-Warning -Message "Unable to retrieve $($PSCmdlet.ParameterSetName.ToLower()) mailbox: $($PSItem.Exception.Message.TrimStart('|'))"
    }

    # Mailbox statistics
    if ($Summary.Mailbox) {
        try {
            Write-Verbose -Message "Retrieving $($PSCmdlet.ParameterSetName.ToLower()) mailbox statistics ..."
            $Summary.MailboxStatistics = Get-MailboxStatistics -Identity $ExoIdentity -ErrorAction 'Stop'
            $Summary.MailboxStatistics | Add-Member -MemberType 'ScriptMethod' -Name 'ToString' -Value { '{0} items / {1}' -f $this.ItemCount, $this.TotalItemSize } -Force
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }

    # Calendar
    if ($Summary.Mailbox) {
        try {
            Write-Verbose -Message "Retrieving $($PSCmdlet.ParameterSetName.ToLower()) calendar ..."
            $Summary.Calendar = Get-MailboxFolderStatistics -Identity $ExoIdentity -FolderScope 'Calendar' -ErrorAction 'Stop' | Where-Object FolderType -EQ 'Calendar'
            $Summary.Calendar | Add-Member -MemberType 'ScriptMethod' -Name 'ToString' -Value { $this.VisibleItemsInFolder } -Force
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }

    # Groups
    if ($PSCmdlet.ParameterSetName -eq 'User' -and $Summary.Mailbox) {
        try {
            Write-Verbose -Message 'Retrieving user group ownership ...'
            $ExoRecipientFilter = 'ManagedBy -eq "{0}"' -f $Summary.Mailbox.DistinguishedName
            $Summary.Groups = @(Get-Recipient -Filter $ExoRecipientFilter -RecipientTypeDetails 'GroupMailbox' -ErrorAction 'Stop')
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }

    # OneDrive / SharePoint site
    try {
        Write-Verbose -Message "Retrieving $($PSCmdlet.ParameterSetName.ToLower()) site ..."
        $SpsProvisioned = $false
        switch ($PSCmdlet.ParameterSetName) {
            'User' {
                $OrgInfo = Get-MgOrganization -ErrorAction 'Stop'
                $DefaultDomain = $OrgInfo.VerifiedDomains | Where-Object IsDefault -EQ $true
                $TenantName = $DefaultDomain.Name.Split('.')[0]
                $SPOSiteFilter = 'Url -like "https://{0}-my.sharepoint.com/personal/*" -and Owner -eq "{1}"' -f $TenantName, $Summary.User.UserPrincipalName
                $PersonalSite = Get-SPOSite -Filter $SPOSiteFilter -IncludePersonalSite:$true -ErrorAction 'Stop'

                if ($PersonalSite) {
                    $Summary.OneDrive = Get-SPOSite -Identity $PersonalSite.Url -Detailed -ErrorAction 'Stop'
                    $Summary.OneDrive | Add-Member -MemberType 'ScriptMethod' -Name 'ToString' -Value { $this.StorageUsageCurrent } -Force
                    $SpsProvisioned = $true
                } else {
                    Write-Warning -Message 'OneDrive has not yet been provisioned or user is not licensed.'
                }
            }

            'Group' {
                if ($Summary.Group.SharePointSiteUrl) {
                    $Summary.Site = Get-SPOSite -Identity $Summary.Group.SharePointSiteUrl -Detailed -ErrorAction 'Stop'
                    $Summary.Site | Add-Member -MemberType 'ScriptMethod' -Name 'ToString' -Value { $this.StorageUsageCurrent } -Force
                    $SpsProvisioned = $true
                } else {
                    Write-Warning -Message 'SharePoint site for group has not yet been provisioned.'
                }
            }
        }
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    # Teams
    if ($PSCmdlet.ParameterSetName -eq 'Group' -and $Summary.Group.ResourceProvisioningOptions -contains 'Team') {
        try {
            Write-Verbose -Message 'Retrieving group teams ...'
            $Summary.Teams = @(Get-Team -GroupId $Summary.Group.ExternalDirectoryObjectId -ErrorAction 'Stop')
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }

    # OneNote
    # https://learn.microsoft.com/en-au/graph/api/resources/onenote-api-overview
    if ($SpsProvisioned) {
        try {
            Write-Verbose -Message "Retrieving $($PSCmdlet.ParameterSetName.ToLower()) notebooks ..."
            switch ($PSCmdlet.ParameterSetName) {
                'User' {
                    $Summary.Notebooks = @(Get-MgUserOnenoteNotebook -UserId $Summary.User.UserPrincipalName -ErrorAction 'Stop')
                    $Summary.NotebookSections = @(Get-MgUserOnenoteSection -UserId $Summary.User.UserPrincipalName -ErrorAction 'Stop')
                    $Summary.NotebookPages = @(Get-MgUserOnenotePage -UserId $Summary.User.UserPrincipalName -ErrorAction 'Stop')
                }

                'Group' {
                    $Summary.Notebooks = @(Get-MgGroupOnenoteNotebook -GroupId $Summary.Group.ExternalDirectoryObjectId -ErrorAction 'Stop')
                    $Summary.NotebookSections = @(Get-MgGroupOnenoteSection -GroupId $Summary.Group.ExternalDirectoryObjectId -ErrorAction 'Stop')
                    $Summary.NotebookPages = @(Get-MgGroupOnenotePage -GroupId $Summary.Group.ExternalDirectoryObjectId -ErrorAction 'Stop')
                }
            }
        } catch { Write-Warning -Message $_.ErrorDetails }
    }

    # Planner
    # https://learn.microsoft.com/en-au/graph/api/resources/planner-overview
    if ($PSCmdlet.ParameterSetName -eq 'Group' -and $SpsProvisioned) {
        try {
            Write-Verbose -Message 'Retrieving group plans ...'
            $Summary.Plans = @(Get-MgGroupPlannerPlan -GroupId $Summary.Group.ExternalDirectoryObjectId -ErrorAction 'Stop')
        } catch { Write-Warning -Message $_.ErrorDetails }
    }

    return $Summary
}

# Retrieve a security report for all users
# Improved version of: https://github.com/OfficeDev/O365-InvestigationTooling/blob/master/DumpDelegatesandForwardingRules.ps1
Function Get-Microsoft365UserSecurityReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(1, 90)]
        [Int]$AccountInactiveDays = 30
    )

    Test-CommandAvailable -Name 'Get-Mailbox', 'Get-MsolUser'

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
        Sort-Object -Property 'UserPrincipalName' |
        ForEach-Object {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name 'IsActive' -Value $false
            Add-Member -InputObject $_ -MemberType ScriptProperty -Name 'IsFederated' -Value { if ($null -ne $this.ImmutableId) { $true } else { $false } }
            Add-Member -InputObject $_ -MemberType ScriptProperty -Name 'StrongAuthenticationState' -Value { $this.StrongAuthenticationRequirements.State }
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

    Test-CommandAvailable -Name 'Get-UnifiedGroup'

    $WriteProgressParams = @{
        Activity = 'Retrieving Unified Group report'
    }

    if (!$Groups) {
        Write-Progress @WriteProgressParams -Status 'Retrieving Microsoft 365 groups' -PercentComplete 1
        $Groups = Get-UnifiedGroup
    }

    $GroupsDone = 0
    foreach ($Group in $Groups) {
        Write-Progress @WriteProgressParams -Status ('Retrieving group: {0}' -f $Group.Identity) -PercentComplete ($GroupsDone / $Groups.Count * 90 + 10)

        Write-Progress @WriteProgressParams -CurrentOperation 'Retrieving owners'
        $Owners = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Owners
        if ($Owners) {
            $AllOwners = ($Owners | Sort-Object) -join ', '
            Add-Member -InputObject $Group -MemberType NoteProperty -Name 'Owners' -Value $AllOwners -Force
        }

        Write-Progress @WriteProgressParams -CurrentOperation 'Retrieving members'
        $Members = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Members
        if ($Members) {
            $AllMembers = ($Members | Sort-Object) -join ', '
            Add-Member -InputObject $Group -MemberType NoteProperty -Name 'Members' -Value $AllMembers -Force
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

    foreach ($RefAlert in ($ReferenceObject | Sort-Object -Property 'Name')) {
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

    foreach ($DiffAlert in ($DifferenceObject | Sort-Object -Property 'Name')) {
        $RefAlert = $ReferenceObject | Where-Object Name -EQ $DiffAlert.Name
        if (!$RefAlert) {
            Write-Warning -Message ('[ID: {0}] Difference alert with no associated reference alert (Ref Name: {1}).' -f $DiffAlert.ImmutableId, $DiffAlert.Name)
            continue
        }
    }

    return $Results.ToArray()
}

#endregion

#region Service connection helpers

# Helper function to connect to all Microsoft 365 services
Function Connect-Microsoft365Services {
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
        Test-ModuleAvailable -Name 'ExchangeOnlineManagement'
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
        $ExoModuleCurrentVersion = Get-Module -Name 'ExchangeOnlineManagement' -ListAvailable -Verbose:$false | Select-Object -First 1 -ExpandProperty 'Version'
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
            $ExchangeOnline = New-PSSession -ConfigurationName 'Microsoft.Exchange' -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
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

    Test-ModuleAvailable -Name 'O365CentralizedAddInDeployment'

    Write-Host -ForegroundColor Green 'Connecting to Microsoft 365 Centralized Deployment ...'
    Connect-OrganizationAddInService @PSBoundParameters
}

# Helper function to connect to Microsoft Teams
Function Connect-MicrosoftTeams {
    [CmdletBinding()]
    #[OutputType([Microsoft.TeamsCmdlets.Powershell.Connect.Models.PSAzureContext])]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    Test-ModuleAvailable -Name 'MicrosoftTeams'

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
        Test-ModuleAvailable -Name 'ExchangeOnlineManagement'
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
        $ExoModuleCurrentVersion = Get-Module -Name 'ExchangeOnlineManagement' -ListAvailable -Verbose:$false | Select-Object -First 1 -ExpandProperty 'Version'
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
            $SCC = New-PSSession -ConfigurationName 'Microsoft.Exchange' -ConnectionUri 'https://ps.compliance.protection.outlook.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
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

    Test-ModuleAvailable -Name 'Microsoft.Online.SharePoint.PowerShell'

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

    if (Get-Command -Name 'Connect-EXOPSSession' -ErrorAction Ignore) {
        return
    }

    $ClickOnceAppsPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Apps\2.0'
    $ExoPowerShellManifest = Get-ChildItem -LiteralPath $ClickOnceAppsPath -Recurse | Where-Object Name -EQ 'Microsoft.Exchange.Management.ExoPowershellModule.manifest' | Sort-Object -Property 'LastWriteTime' | Select-Object -Last 1
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
        $null = New-Item -Path 'Function:' -Name "Global:$Function" -Value (Get-Content -LiteralPath Function:\$Function)
    }
}

#endregion

Complete-DotFilesSection
