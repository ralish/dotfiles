if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

try {
    if (!$DotFilesFastLoad) {
        Test-ModuleAvailable -Name ExchangeOnlineManagement
    }
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ExchangeOnline settings as module not found.')
    $Error.RemoveAt(0)
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading ExchangeOnline settings ...')

# Mailbox properties we may want to ignore
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
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
