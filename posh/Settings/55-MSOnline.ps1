$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'MSOnline'
    Platform = 'Windows'
    Module   = @('MSOnline')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# User properties we may want to ignore
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$MsolUserIgnoredProperties = @(
    # User identity
    'ImmutableId',
    'LiveId',
    'SignInName',
    #'UserPrincipalName',

    # User settings
    'PortalSettings',
    'UserLandingPageIdentifierForO365Shell',
    'UserThemeIdentifierForO365Shell',

    # GUIDs
    'ObjectId',

    # Timestamps
    'LastDirSyncTime',
    'LastPasswordChangeTimestamp',
    'SoftDeletionTimestamp',
    'StrongAuthenticationProofupTime',
    'StsRefreshTokensValidFrom',
    'WhenCreated'
)

Complete-DotFilesSection
