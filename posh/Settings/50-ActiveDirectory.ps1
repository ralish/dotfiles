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
    $Error.RemoveAt(0)
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading ActiveDirectory settings ...')

# AD class properties we may want to ignore: top
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$ADClassIgnoredPropertiesTop = @(
    # Only exposed via LDAP attributes
    'dSCorePropagationData'
    'mS-DS-ConsistencyGuid'
    'uSNChanged'
    'uSNCreated'
    'whenChanged'
    'whenCreated'

    # PoSh property followed by equivalent LDAP attribute
    'Created', 'createTimeStamp'
    'Modified', 'modifyTimeStamp'

    # LDAP attributes & PoSh properties differing only in case
    'CanonicalName'                 # canonicalName
    'CN'                            # cn
    'DistinguishedName'             # distinguishedName
    'ObjectGUID'                    # objectGUID

    # Interesting but duplicated properties
    'Deleted'                       # isDeleted
)

# AD class properties we may want to ignore: securityPrincipal
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$ADClassIgnoredPropertiesSecurityPrincipal = $ADClassIgnoredPropertiesTop + @(
    # PoSh property followed by equivalent LDAP attribute
    'SID', 'objectSid'

    # LDAP attributes & PoSh properties differing only in case
    'MemberOf'                      # memberOf
)

# AD class properties we may want to ignore: user
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$ADClassIgnoredPropertiesUser = $ADClassIgnoredPropertiesSecurityPrincipal + @(
    # Only exposed via LDAP attributes
    'lastLogoff'
    'lastLogon'
    'logonCount'
    'msDS-KeyCredentialLink'

    # PoSh property followed by equivalent LDAP attribute
    'AccountLockoutTime', 'lockoutTime'
    'BadLogonCount', 'badPwdCount'
    'LastBadPasswordAttempt', 'badPasswordTime'
    'LastLogonDate', 'lastLogonTimestamp'
    'PasswordLastSet', 'pwdLastSet'

    # Interesting but duplicated properties: person
    'OfficePhone'                   # telephoneNumber
    'Surname'                       # sn

    # Interesting but duplicated properties: organizationalPerson
    'City'                          # l
    'Country'                       # c
    'Fax'                           # facsimileTelephoneNumber
    'Office'                        # physicalDeliveryOfficeName
    'OtherName'                     # middleName
    'POBox'                         # postOfficeBox
    'State'                         # st

    # Interesting but duplicated properties: user
    'AccountExpirationDate'         # accountExpires
    'EmailAddress'                  # mail
    'MobilePhone'                   # mobile
    'Organization'                  # o
)
