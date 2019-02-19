# Load our custom formatting data
Update-FormatData -PrependPath (Join-Path -Path $PSScriptRoot -ChildPath 'Office 365.format.ps1xml')

# Helper function to connect to all Office 365 services
Function Connect-Office365Services {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName='Standard', Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential,

        [Parameter(Mandatory)]
        [String]$SharePointTenantName
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-ExchangeOnline -MfaUsername $MfaUsername
    } else {
        Connect-ExchangeOnline -Credential $Credential
    }

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-SecurityAndComplianceCenter -MfaUsername $MfaUsername
    } else {
        Connect-SecurityAndComplianceCenter -Credential $Credential
    }

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-SharePointOnline -TenantName $SharePointTenantName
    } else {
        Connect-SharePointOnline -TenantName $SharePointTenantName -Credential $Credential
    }

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-SkypeForBusinessOnline -MfaUsername $MfaUsername
    } else {
        Connect-SkypeForBusinessOnline -Credential $Credential
    }

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Write-Warning -Message "Unable to connect to Office 365 Centralized Deployment as it doesn't support MFA."
    } else {
        Connect-Office365CentralizedDeployment -Credential $Credential
    }
}

# Helper function to connect to Exchange Online
Function Connect-ExchangeOnline {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName='Standard', Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Import-ExoPowershellModule
    }

    Write-Host -ForegroundColor Green -Object 'Connecting to Exchange Online ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-EXOPSSession -UserPrincipalName $MfaUsername
    } else {
        $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
        Import-PSSession -Session $ExchangeOnline
    }
}

# Helper function to connect to Centralized Deployment
Function Connect-Office365CentralizedDeployment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    Test-ModuleAvailable -Name OrganizationAddInService

    Write-Host -ForegroundColor Green -Object 'Connecting to Office 365 Centralized Deployment ...'
    Connect-OrganizationAddInService @PSBoundParameters
}

# Helper function to connect to Security & Compliance Center
Function Connect-SecurityAndComplianceCenter {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName='Standard', Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Import-ExoPowershellModule
    }

    Write-Host -ForegroundColor Green -Object 'Connecting to Security and Compliance Center ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-IPPSSession -UserPrincipalName $MfaUsername
    } else {
        $SCC = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://ps.compliance.protection.outlook.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
        Import-PSSession -Session $SCC
    }
}

# Helper function to connect to SharePoint Online
Function Connect-SharePointOnline {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$TenantName,

        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    Test-ModuleAvailable -Name Microsoft.Online.SharePoint.PowerShell

    Write-Host -ForegroundColor Green -Object 'Connecting to SharePoint Online ...'
    $SPOUrl = 'https://{0}-admin.sharepoint.com' -f $TenantName
    if ($Credential) {
        Connect-SPOService -Url $SPOUrl -Credential $Credential
    } else {
        Connect-SPOService -Url $SPOUrl
    }
}

# Helper function to connect to Skype for Business Online
Function Connect-SkypeForBusinessOnline {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName='Standard', Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    Test-ModuleAvailable -Name SkypeOnlineConnector

    # Fix a scope issue due to variable reuse by SkypeOnlineConnector?
    if (-not $PSBoundParameters.ContainsKey('MfaUsername')) {
        Remove-Variable -Name MfaUsername
    }
    if (-not $PSBoundParameters.ContainsKey('Credential')) {
        Remove-Variable -Name Credential
    }

    Write-Host -ForegroundColor Green -Object 'Connecting to Skype for Business Online ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        $CsOnlineSession = New-CsOnlineSession -UserName $MfaUsername
    } else {
        $CsOnlineSession = New-CsOnlineSession -Credential $Credential
    }
    Import-PSSession -Session $CsOnlineSession
}

# Export mailbox data for our email management spreadsheet
Function Export-MailboxSpreadsheetData {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Mailbox,

        [IO.DirectoryInfo]$Path,
        [DateTime]$StartDate,
        [DateTime]$EndDate,

        [ValidateNotNullOrEmpty()]
        [String]$DescriptionTimeZone,

        [ValidateNotNullOrEmpty()]
        [String]$DescriptionTimeFormat
    )

    Test-CommandAvailable -Name Get-Mailbox

    if (-not $PSBoundParameters.ContainsKey('Path')) {
        if ((Get-Item -Path $PWD) -is [IO.DirectoryInfo]) {
            $Path = Get-Item -Path $PWD
        } else {
            Write-Warning -Message 'Defaulting to $HOME as $PWD is not a directory.'
            $Path = $HOME
        }
    }

    Write-Host -ForegroundColor Green -Object 'Retrieving mailbox details ...'
    $ExoMailbox = Get-Mailbox -Identity $Mailbox
    $MailboxAddress = $ExoMailbox.PrimarySmtpAddress

    $Params = @{ Mailbox=$Mailbox }
    foreach ($Parameter in @('StartDate', 'EndDate')) {
        if ($PSBoundParameters.ContainsKey($Parameter)) {
            $Params.Add($Parameter, $PSBoundParameters.Item($Parameter))
        }
    }
    $Activity = Get-MailboxActivitySummary -Mailbox $Mailbox

    $Params = @{ Mailbox=$Mailbox }
    foreach ($Parameter in @('DescriptionTimeZone', 'DescriptionTimeFormat')) {
        if ($PSBoundParameters.ContainsKey($Parameter)) {
            $Params.Add($Parameter, $PSBoundParameters.Item($Parameter))
        }
    }
    $Folders = Get-InboxRulesByFolders @Params

    Write-Host -ForegroundColor Green -Object 'Retrieving mailbox rules ...'
    $Rules = Get-InboxRule -DescriptionTimeZone $DescriptionTimeZone -DescriptionTimeFormat $DescriptionTimeFormat

    Write-Host -ForegroundColor Green -Object 'Exporting mailbox data ...'
    $Params = @{
        Encoding='UTF8'
        NoTypeInformation=$true
    }
    $Activity | Export-Csv @Params -Path (Join-Path -Path $Path -ChildPath 'Activity Summary.csv') -Append
    $Folders | Export-Csv @Params -Path (Join-Path -Path $Path -ChildPath ('{0} - Folders.csv' -f $MailboxAddress))
    $Rules | Export-Csv @Params -Path (Join-Path -Path $Path -ChildPath ('{0} - Rules.csv' -f $MailboxAddress))
}

# Retrieve a summary of mailbox folders with associated rules
Function Get-InboxRulesByFolders {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Mailbox,

        [ValidateNotNullOrEmpty()]
        [String]$DescriptionTimeZone='AUS Eastern Standard Time',

        [ValidateNotNullOrEmpty()]
        [String]$DescriptionTimeFormat='yyyy/mm/dd'
    )

    Test-CommandAvailable -Name Get-MailboxFolder

    Write-Host -ForegroundColor Green -Object 'Retrieving mailbox folders ...'
    $Folders = Get-MailboxFolder -Identity ('{0}:\Inbox' -f $Mailbox) -MailFolderOnly -Recurse | Where-Object { $_.DefaultFolderType -ne 'Inbox' }
    $Folders | Add-Member -MemberType NoteProperty -Name Rules -Value @()
    $Folders | Add-Member -MemberType ScriptProperty -Name RuleCount -Value { $this.Rules.Count }

    Write-Host -ForegroundColor Green -Object 'Retrieving mailbox rules ...'
    $Rules = Get-InboxRule -DescriptionTimeZone $DescriptionTimeZone -DescriptionTimeFormat $DescriptionTimeFormat
    $Rules | Add-Member -MemberType NoteProperty -Name LinkedToFolder -Value $false

    Write-Host -ForegroundColor Green -Object 'Associating mailbox rules to folders ...'
    $Results = @()
    foreach ($Folder in $Folders) {
        $FolderDashName = ($Folder.FolderPath -join ' - ').Substring(8)

        foreach ($Rule in ($Rules | Where-Object { $_.LinkedToFolder -eq $false })) {
            if ($Rule.Name -match ('^{0}' -f $FolderDashName) -and $Rule.MoveToFolder -eq $Folder.Name) {
                $Rule.LinkedToFolder = $true
                $Folder.Rules += $Rule
            }
        }

        $Results += $Folder
    }

    $UnlinkedRules = $Rules | Where-Object { $_.LinkedToFolder -eq $false }
    if ($UnlinkedRules) {
        Write-Host -ForegroundColor Yellow -Object ('Number of unlinked rules: {0}' -f ($UnlinkedRules | Measure-Object).Count)
    }

    return $Folders
}

# Retrieve a summary of sent & received totals for a mailbox
Function Get-MailboxActivitySummary {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Mailbox,

        [DateTime]$StartDate,
        [DateTime]$EndDate
    )

    Test-CommandAvailable -Name Get-Mailbox

    if (-not $PSBoundParameters.ContainsKey('EndDate')) {
        $EndDate = Get-Date
    }

    if (-not $PSBoundParameters.ContainsKey('StartDate')) {
        $StartDate = $EndDate.AddDays(-7)
    }

    $TraceParams = $PSBoundParameters
    $null = $TraceParams.Remove('Mailbox')

    Write-Host -ForegroundColor Green -Object 'Retrieving mailbox details ...'
    $ExoMailbox = Get-Mailbox -Identity $Mailbox
    $Addresses = $ExoMailbox.EmailAddresses | Where-Object { $_ -match '^smtp:' } | ForEach-Object { $_.Substring(5) }

    Write-Host -ForegroundColor Green -Object 'Retrieving mailbox send logs ...'
    $Sent = Get-MessageTrace @TraceParams -SenderAddress $Addresses

    Write-Host -ForegroundColor Green -Object 'Retrieving mailbox receive logs ...'
    $Received = Get-MessageTrace @TraceParams -RecipientAddress $Addresses

    $Summary = [PSCustomObject]@{
        Mailbox     = $ExoMailbox.PrimarySmtpAddress
        StartDate   = $StartDate.ToString()
        EndDate     = $EndDate.ToString()
        Sent        = ($Sent | Measure-Object).Count
        Received    = ($Received | Measure-Object).Count
    }

    return $Summary
}

# Retrieve a summary of users with delegates or forwarding rules
# Improved version of: https://github.com/OfficeDev/O365-InvestigationTooling/blob/master/DumpDelegatesandForwardingRules.ps1
Function Get-MailboxDelegatesAndForwardingRules {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param()

    Test-CommandAvailable -Name @('Get-InboxRule', 'Get-MsolUser')

    $Delegates = @()
    $ForwardingRules = @()
    $MailboxForwarding = @()

    $Users = Get-MsolUser -All -EnabledFilter EnabledOnly -ErrorAction Stop | Where-Object { $_.UserType -ne 'Guest' }

    $Users | ForEach-Object {
        Add-Member -InputObject $_ -MemberType ScriptProperty -Name IsFederated -Value { if ($null -ne $this.ImmutableId) { $true } else { $false } }
        Add-Member -InputObject $_ -MemberType ScriptProperty -Name StrongAuthenticationState -Value { $this.StrongAuthenticationRequirements.State }
        $_.PSObject.TypeNames.Insert(0, 'Microsoft.Online.Administration.User.Security')
    }

    $Mailboxes = Get-Mailbox -ResultSize Unlimited

    $MailboxForwarding += $Mailboxes |
        Where-Object { $null -ne $_.ForwardingSmtpAddress }

    $MailboxForwarding | ForEach-Object {
        $_.PSObject.TypeNames.Insert(0, 'Deserialized.Microsoft.Exchange.Data.Directory.Management.Mailbox.Security')
    }

    foreach ($Mailbox in $Mailboxes) {
        Write-Verbose -Message ('Checking delegates and forwarding rules for user: {0}' -f $Mailbox.UserPrincipalName)

        $Delegates += Get-MailboxPermission -Identity $Mailbox.UserPrincipalName |
            Where-Object { ($_.IsInherited -ne 'True') -and ($_.User -notlike '*SELF*') }

        $Delegates | ForEach-Object {
            $_.PSObject.TypeNames.Insert(0, 'Deserialized.Microsoft.Exchange.Management.RecipientTasks.MailboxAcePresentationObject.Security')
        }

        $ForwardingRules += Get-InboxRule -Mailbox $Mailbox.UserPrincipalname |
            Where-Object { ($null -ne $_.ForwardTo) -or ($null -ne $_.ForwardAsAttachmentTo) -or ($null -ne $_.RedirectTo) }

        $ForwardingRules | ForEach-Object {
            $_.PSObject.TypeNames.Insert(0, 'Deserialized.Microsoft.Exchange.Management.Common.InboxRule.Security')
        }
    }

    $Results = [PSCustomObject]@{
        Users               = $Users
        Delegates           = $Delegates
        ForwardingRules     = $ForwardingRules
        MailboxForwarding   = $MailboxForwarding
    }

    return $Results
}

# Retrieve a report on unified groups with owner & member details
Function Get-UnifiedGroupReport {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$Groups
    )

    Test-CommandAvailable -Name Get-UnifiedGroup

    if (!$Groups) {
        Write-Host -ForegroundColor Green -Object 'Retrieving Office 365 groups ...'
        $Groups = Get-UnifiedGroup
    }

    foreach ($Group in $Groups) {
        Write-Host -ForegroundColor Green -Object ('Now processing: {0}' -f $Group.Identity)

        Write-Verbose -Message ('[{0}] Retrieving owners ...' -f $Group.Identity)
        $Owners = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Owners
        if ($Owners) {
            $AllOwners = [String]::Join(', ', ($Owners | Sort-Object))
            Add-Member -InputObject $Group -MemberType NoteProperty -Name Owners -Value $AllOwners -Force
        }

        Write-Verbose -Message ('[{0}] Retrieving members ...' -f $Group.Identity)
        $Members = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Members
        if ($Members) {
            $AllMembers = [String]::Join(', ', ($Members | Sort-Object))
            Add-Member -InputObject $Group -MemberType NoteProperty -Name Members -Value $AllMembers -Force
        }
    }

    return $Groups
}

# Retrieve a usage summary for a unified group
Function Get-UnifiedGroupUsageSummary {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseConsistentWhitespace', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Identity,

        [Parameter(Mandatory)]
        [String]$TenantName,

        [Parameter(Mandatory)]
        [Guid]$ClientId,

        [Parameter(Mandatory)]
        [String]$RedirectUri
    )

    # Group
    Write-Verbose -Message 'Retrieving group data ...'
    $UnifiedGroup = Get-UnifiedGroup -Identity $Identity -IncludeAllProperties

    # Mailbox
    Write-Verbose -Message 'Retrieving mailbox data ...'
    $Mailbox = Get-Mailbox -Identity $UnifiedGroup.PrimarySmtpAddress -GroupMailbox
    $MailboxStatistics = Get-MailboxStatistics -Identity $UnifiedGroup.PrimarySmtpAddress

    # Calendar
    Write-Verbose -Message 'Retrieving calendar data ...'
    $Calendar = Get-MailboxFolderStatistics -Identity $UnifiedGroup.PrimarySmtpAddress -FolderScope Calendar

    # Site
    Write-Verbose -Message 'Retrieving site data ...'
    $SPOSite = Get-SPOSite -Identity $UnifiedGroup.SharePointSiteUrl -Detailed

    # Notebook
    Write-Verbose -Message 'Retrieving OneNote data ...'
    Write-Warning -Message 'Not yet implemented!'

    # Graph API setup
    Write-Verbose -Message 'Connecting to Microsoft Graph API ...'
    $GraphApiAuthToken = Get-AzureAuthToken -Api MsGraph -TenantName $TenantName -ClientId $ClientId -RedirectUri $RedirectUri
    $GraphApiAuthHeader = Get-AzureAuthHeader -AuthToken $GraphApiAuthToken.Result

    # Planner
    # https://docs.microsoft.com/en-us/graph/api/resources/planner-overview?view=graph-rest-1.0
    Write-Verbose -Message 'Retrieving Planner data ...'
    $GraphApiPlannerPlans = 'https://graph.microsoft.com/v1.0/groups/{0}/planner/plans' -f $UnifiedGroup.ExternalDirectoryObjectId
    $Planner = Invoke-RestMethod -Uri $GraphApiPlannerPlans -Headers $GraphApiAuthHeader -Method Get

    # Teams
    # https://docs.microsoft.com/en-us/graph/api/resources/teams-api-overview?view=graph-rest-1.0
    Write-Verbose -Message 'Retrieving Teams data ...'
    Write-Warning -Message 'Not yet implemented!'

    $Summary = [PSCustomObject]@{
        Group               = $UnifiedGroup

        Mailbox             = $Mailbox
        MailboxStatistics   = $MailboxStatistics
        MailboxItems        = $MailboxStatistics.ItemCount
        MailboxSize         = $MailboxStatistics.TotalItemSize

        Calendar            = $Calendar
        CalendarItems       = $Calendar.VisibleItemsInFolder

        SPOSite             = $SPOSite
        SPOSiteSize         = $SPOSite.StorageUsageCurrent

        Notebook            = $null

        Planner             = $Planner

        Teams               = $null
    }

    return $Summary
}

# Helper function to import the weird Exchange Online PowerShell module
Function Import-ExoPowershellModule {
    [CmdletBinding()]
    Param()

    if (!(Get-Command -Name Connect-EXOPSSession -ErrorAction Ignore)) {
        Write-Verbose -Message 'Importing Microsoft.Exchange.Management.ExoPowershellModule ...'

        $ClickOnceAppsPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Apps\2.0'
        $ExoPowerShellModule = Get-ChildItem -Path $ClickOnceAppsPath -Recurse -Include 'Microsoft.Exchange.Management.ExoPowershellModule.manifest' | Sort-Object -Property LastWriteTime | Select-Object -Last 1
        $ExoPowerShellModulePs1 = Join-Path -Path $ExoPowerShellModule.Directory -ChildPath 'CreateExoPSSession.ps1'

        if ($ExoPowerShellModule) {
            # Sourcing the script rudely changes the current working directory
            $CurrentPath = Get-Location
            . $ExoPowerShellModulePs1
            Set-Location -Path $CurrentPath

            # Change the scope of imported functions to be global (better approach?)
            $Functions = @('Connect-EXOPSSession', 'Connect-IPPSSession', 'Test-Uri')
            foreach ($Function in $Functions) {
                $null = New-Item -Path Function: -Name global:$Function -Value (Get-Content -Path Function:\$Function)
            }
        } else {
            throw 'Required module not available: Microsoft.Exchange.Management.ExoPowershellModule'
        }
    }
}
