# Active Directory
# https://learn.microsoft.com/en-au/powershell/module/activedirectory/

$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'Active Directory'
    Module   = 'ActiveDirectory'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup `ActiveDirectory` configuration
Function Initialize-ActiveDirectory {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Class: `top`
    # Properties we may want to ignore.
    $Global:ADClassIgnoredPropertiesTop = @(
        # Only exposed via LDAP attributes
        'dSCorePropagationData'
        'mS-DS-ConsistencyGuid'
        'uSNChanged'
        'uSNCreated'
        'whenChanged'
        'whenCreated'

        # PowerShell property followed by equivalent LDAP attribute
        'Created', 'createTimeStamp'
        'Modified', 'modifyTimeStamp'

        # LDAP attributes & PowerShell properties differing only in case
        'CanonicalName'                 # canonicalName
        'CN'                            # cn
        'DistinguishedName'             # distinguishedName
        'ObjectGUID'                    # objectGUID

        # Interesting but duplicated properties
        'Deleted'                       # isDeleted
    )

    # Class: `securityPrincipal`
    # Properties we may want to ignore.
    $Global:ADClassIgnoredPropertiesSecurityPrincipal = $ADClassIgnoredPropertiesTop + @(
        # PowerShell property followed by equivalent LDAP attribute
        'SID', 'objectSid'

        # LDAP attributes & PowerShell properties differing only in case
        'MemberOf'                      # memberOf
    )

    # Class: `user`
    # Properties we may want to ignore.
    $Global:ADClassIgnoredPropertiesUser = $ADClassIgnoredPropertiesSecurityPrincipal + @(
        # Only exposed via LDAP attributes
        'lastLogoff'
        'lastLogon'
        'logonCount'
        'msDS-KeyCredentialLink'

        # PowerShell property followed by equivalent LDAP attribute
        'AccountLockoutTime', 'lockoutTime'
        'BadLogonCount', 'badPwdCount'
        'LastBadPasswordAttempt', 'badPasswordTime'
        'LastLogonDate', 'lastLogonTimestamp'
        'PasswordLastSet', 'pwdLastSet'

        # Interesting but duplicated properties: `person`
        'OfficePhone'                   # telephoneNumber
        'Surname'                       # sn

        # Interesting but duplicated properties: `organizationalPerson`
        'City'                          # l
        'Country'                       # c
        'Fax'                           # facsimileTelephoneNumber
        'Office'                        # physicalDeliveryOfficeName
        'OtherName'                     # middleName
        'POBox'                         # postOfficeBox
        'State'                         # st

        # Interesting but duplicated properties: `user`
        'AccountExpirationDate'         # accountExpires
        'EmailAddress'                  # mail
        'MobilePhone'                   # mobile
        'Organization'                  # o
    )
}

Initialize-ActiveDirectory

Remove-Item -LiteralPath 'Function:\Initialize-ActiveDirectory'
Complete-DotFilesSection
