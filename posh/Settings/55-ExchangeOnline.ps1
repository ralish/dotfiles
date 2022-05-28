$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'Exchange Online'
    Platform = 'Windows'
    Module   = @('ExchangeOnlineManagement')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Mailbox properties we may want to ignore
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$ExoMailboxIgnoredProperties = @(
    # User identity
    'MicrosoftOnlineServicesID',
    'WindowsEmailAddress',
    'WindowsLiveID',

    # Mailbox identity
    #'Alias',
    'DistinguishedName',
    #'Id',
    'Identity',
    'LegacyExchangeDN',
    'Name',
    'NetID',
    'SamAccountName',
    #'UserPrincipalName',

    # Mailbox internal
    'MailboxLocations',
    'MailboxRelease',

    # Server internal
    'Database',
    'ServerLegacyDN',
    'ServerName',

    # GUIDs
    'DatabaseGuid',
    'ExchangeGuid',
    'ExchangeObjectId',
    'ExternalDirectoryObjectId',
    'Guid',

    # Timestamps
    'EnforcedTimestamps',
    'StsRefreshTokensValidFrom',
    'WhenChanged',
    'WhenChangedUTC',
    'WhenCreated',
    'WhenCreatedUTC',
    'WhenMailboxCreated'
)

Complete-DotFilesSection
