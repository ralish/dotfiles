# Exchange Online
# https://learn.microsoft.com/en-au/powershell/exchange/exchange-online-powershell

$DotFilesSection = @{
    Type   = 'Settings'
    Name   = 'Exchange Online'
    Module = 'ExchangeOnlineManagement'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup `ExchangeOnlineManagement` configuration
Function Initialize-ExchangeOnlineManagement {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Add an alias for the unintuitively named `Connect-IPPSSession`
    Set-Alias -Name 'Connect-SecurityAndCompliance' -Value 'Connect-IPPSSession' -Scope 'Global'

    # Type: Mailbox
    # Properties we may want to ignore.
    $Global:ExoMailboxIgnoredProperties = @(
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
}

Initialize-ExchangeOnlineManagement

Remove-Item -LiteralPath 'Function:\Initialize-ExchangeOnlineManagement'
Complete-DotFilesSection
