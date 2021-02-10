if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

try {
    if (!$DotFilesFastLoad) {
        Test-ModuleAvailable -Name MSOnline
    }
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping MSOnline settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading MSOnline settings ...')

# Mailbox properties we usually don't care about
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$MsolUserIgnoredProperties = @(
    # User identity
    'ImmutableId',
    'LiveId',
    'SignInName',
    #'UserPrincipalName',

    # Uninteresting
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
