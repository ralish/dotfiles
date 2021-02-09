if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

try {
    if (!$DotFilesFastLoad) {
        Test-ModuleAvailable -Name ActiveDirectory
    }
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ActiveDirectory settings as module not found.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading ActiveDirectory settings ...')

# User properties we usually don't care about
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$ADUserIgnoredProperties = @(
    # Only exposed via LDAP attributes
    'dSCorePropagationData',
    'lastLogoff',
    'lockoutTime',
    'logonCount',
    'mS-DS-ConsistencyGuid',
    'msDS-KeyCredentialLink',
    'uSNChanged',
    'uSNCreated',

    # LDAP attributes & PoSh properties with identical names
    'CanonicalName',
    'CN',
    'DistinguishedName',
    'MemberOf',
    'ObjectGUID',

    # PoSh property followed by equivalent LDAP attribute(s)
    'BadLogonCount',
    'badPwdCount',

    'Created',
    'whenCreated',
    'createTimeStamp',

    'LastBadPasswordAttempt',
    'badPasswordTime',

    'LastLogonDate',
    'lastLogon',
    'lastLogonTimestamp',

    'Modified',
    'whenChanged',
    'modifyTimeStamp',

    'PasswordLastSet',
    'pwdLastSet',

    'SID'
    'objectSid',

    # Interesting but duplicated properties
    'mail'                  # EmailAddress
    'mobile'                # MobilePhone
    'sn'                    # Surname
)
