if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

if (!$DotFilesFastLoad) {
    try {
        Test-ModuleAvailable -Name MSOnline
    } catch {
        Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping MSOnline settings as module not found.')
        $Error.RemoveAt(0)
        return
    }
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading MSOnline settings ...')

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
