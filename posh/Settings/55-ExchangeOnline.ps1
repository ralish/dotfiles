# Exchange Online
# https://learn.microsoft.com/en-au/powershell/exchange/exchange-online-powershell

$DotFilesSection = @{
    Type   = 'Settings'
    Name   = 'Exchange Online'
    Module = 'ExchangeOnlineManagement'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Add an alias for the unintuitively named `Connect-IPPSSession`
Set-Alias -Name 'Connect-SecurityAndCompliance' -Value 'Connect-IPPSSession'

# Type: Mailbox
# Properties we may want to ignore.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$ExoMailboxIgnoredProperties = @(
    # User identity
    'MicrosoftOnlineServicesID'
    'WindowsEmailAddress'
    'WindowsLiveID'

    # Mailbox identity
    #'Alias'
    'DistinguishedName'
    #'Id'
    'Identity'
    'LegacyExchangeDN'
    'Name'
    'NetID'
    'SamAccountName'
    #'UserPrincipalName'

    # Mailbox internal
    'MailboxLocations'
    'MailboxRelease'

    # Server internal
    'Database'
    'ServerLegacyDN'
    'ServerName'

    # GUIDs
    'DatabaseGuid'
    'ExchangeGuid'
    'ExchangeObjectId'
    'ExternalDirectoryObjectId'
    'Guid'

    # Timestamps
    'EnforcedTimestamps'
    'StsRefreshTokensValidFrom'
    'WhenChanged'
    'WhenChangedUTC'
    'WhenCreated'
    'WhenCreatedUTC'
    'WhenMailboxCreated'
)

Complete-DotFilesSection
