if (Get-Module -Name ActiveDirectory -ListAvailable) {
    Write-Verbose -Message '[dotfiles] Loading ActiveDirectory settings ...'

    # User properties we usually don't care about
    $ADUserIgnoredProperties = @(
        # Only exposed via LDAP attributes
        'dSCorePropagationData',
        'lastLogoff',
        'logonCount',
        'mS-DS-ConsistencyGuid',
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
        'sn'                    # Surname
    )
} else {
    Write-Verbose -Message '[dotfiles] Skipping ActiveDirectory settings as module not found.'
}
