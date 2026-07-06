$DotFilesSection = @{
    Type   = 'Functions'
    Name   = 'Active Directory'
    Module = 'ActiveDirectory'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Active Directory.format.ps1xml'))

#region Directory schema

# Resolve AD GUIDs corresponding to extended rights or schema objects
Function Global:Resolve-ADGuid {
    [CmdletBinding()]
    [OutputType('Void', 'Microsoft.ActiveDirectory.Management.ADObject[]')]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('ExtendedRight', 'SchemaObject')]
        [String]$Type,

        [Parameter(ParameterSetName = 'Guid', Mandatory, ValueFromPipeline)]
        [Guid[]]$Guid,

        [Parameter(ParameterSetName = 'All', Mandatory)]
        [Switch]$All,

        [ValidateNotNullOrEmpty()]
        [String]$Server
    )

    Begin {
        $CommonParams = @{ ErrorAction = 'Stop' }

        if ($Server) {
            $CommonParams['Server'] = $Server
        }

        try {
            $RootDse = Get-ADRootDSE @CommonParams
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            $LDAPFilters = [Collections.Generic.List[String]]::new()
        }

        switch ($Type) {
            'ExtendedRight' {
                $SearchBase = $RootDse.configurationNamingContext
                $TypeName = 'Microsoft.ActiveDirectory.Management.ADObject.ControlAccessRight'

                if ($PSCmdlet.ParameterSetName -eq 'All') {
                    $LDAPFilter = '(rightsGuid=*)'
                }
            }

            'SchemaObject' {
                $SearchBase = $RootDse.schemaNamingContext
                $TypeName = 'Microsoft.ActiveDirectory.Management.ADObject.SchemaObject'

                if ($PSCmdlet.ParameterSetName -eq 'All') {
                    $LDAPFilter = '(schemaIDGUID=*)'
                }
            }
        }

        Write-Verbose -Message "Using search base: ${SearchBase}"
    }

    Process {
        if ($PSCmdlet.ParameterSetName -ne 'Guid') { return }

        foreach ($ADGuid in $Guid) {
            switch ($Type) {
                'ExtendedRight' {
                    $LDAPFilters.Add("(rightsGuid=${ADGuid})")
                }

                'SchemaObject' {
                    $HexBytes = $ADGuid.ToByteArray() | ForEach-Object { $PSItem.ToString('x2') }
                    $LDAPFilters.Add("(schemaIDGUID=\$($HexBytes -join '\'))")
                }
            }
        }
    }

    End {
        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            # Can occur on an empty pipeline
            if ($LDAPFilters.Count -eq 0) { return }

            $LDAPFilter = "(|$($LDAPFilters -join ''))"
        }

        try {
            Write-Verbose -Message "Using LDAP filter: ${LDAPFilter}"
            $ADObjects = @(Get-ADObject @CommonParams -SearchBase $SearchBase -LDAPFilter $LDAPFilter -Properties '*')
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

        foreach ($ADObject in $ADObjects) {
            $ADObject.PSObject.TypeNames.Insert(0, $TypeName)
        }

        return $ADObjects
    }
}

#endregion

#region Kerberos

# Estimate the Kerberos token size for a user
#
# Problems with Kerberos authentication when a user belongs to many groups
# https://learn.microsoft.com/en-au/troubleshoot/windows-server/windows-security/kerberos-authentication-problems-if-user-belongs-to-groups
Function Global:Get-KerberosTokenSize {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        # Only the `DOMAIN\Username` format is supported (domain is optional)
        [Parameter(Mandatory)]
        [String]$Username,

        [ValidateSet('Windows Server 2008 R2 (or earlier)', 'Windows Server 2012 (or later)')]
        [String]$OperatingSystem = 'Windows Server 2012 (or later)',

        [UInt16]$TicketOverheadBytes = 1200
    )

    $CommonParams = @{ ErrorAction = 'Stop' }

    $UsernameSplit = @($Username.Split('\'))
    if ($UsernameSplit.Count -gt 2) {
        $ExcMsg = 'Expected only a single "\" character to be present in username.'
        $ErrExc = [ArgumentException]::new($ExcMsg, 'Username')
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ADInvalidUsername', $ErrCat, $Username)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($UsernameSplit.Count -eq 2) {
        $User = $UsernameSplit[1]
        $Domain = $UsernameSplit[0]
    } else {
        $User = $Username
        $Domain = $Env:USERDOMAIN
    }

    try {
        $DomainController = Get-ADDomainController @CommonParams -DomainName $Domain -Discover -Service 'GlobalCatalog' -NextClosestSite
        $CommonParams['Server'] = "$($DomainController.HostName.Value):3268"

        $ADUser = Get-ADUser @CommonParams -Identity $User -Properties 'PrimaryGroup', 'SIDHistory', 'TrustedForDelegation'
        $ADUserPrimaryGroup = Get-ADGroup @CommonParams -Identity $ADUser.PrimaryGroup

        # Replacements are to ensure the filter string complies with RFC 4515
        $ADUserDn = $ADUser.DistinguishedName -replace '\\', '\5c' -replace '\*', '\2a' -replace '\(', '\28' -replace '\)', '\29'
        $ADUserPrimaryGroupDn = $ADUserPrimaryGroup.DistinguishedName -replace '\\', '\5c' -replace '\*', '\2a' -replace '\(', '\28' -replace '\)', '\29'

        # LDAP matching rules
        #
        # OID                       Capability name
        # 1.2.840.113556.1.4.803    LDAP_MATCHING_RULE_BIT_AND
        # 1.2.840.113556.1.4.1941   LDAP_MATCHING_RULE_TRANSITIVE_EVAL
        #
        # `groupType` attribute
        #
        # Value                     Description
        # 0x80000000 (2147483648)   Security group
        $LdapGroupsFilter = '(&(groupType:1.2.840.113556.1.4.803:=2147483648)(|(member:1.2.840.113556.1.4.1941:={0})(member:1.2.840.113556.1.4.1941:={1})))' -f $ADUserDn, $ADUserPrimaryGroupDn

        # The groups present in the Kerberos PAC are built from the transitive
        # closure of security group memberships (all of domain local, global,
        # and universal). This is more difficult to retrieve than you'd expect.
        #
        # Using `Get-ADPrincipalGroupMembership` is insufficient as it doesn't
        # handle transitive group memberships. Naively consulting the user's
        # `memberOf` attribute isn't enough either as:
        # - It does not include the user's primary group
        # - It only contains direct group memberships (not transitive)
        # - It includes distribution groups (not relevant)
        #
        # Instead, construct an LDAP filter that requests transitive evaluation
        # of group memberships and explicitly add the user's primary group. The
        # empty value for `SearchBase` ensures we search from the root of the
        # LDAP tree so membership in foreign universal groups is included. If
        # unspecified, the default naming context of the target domain is used
        # which negates the purpose of querying the Global Catalog server.
        #
        # There are still some instances which are not handled which can result
        # in the calculated Kerberos token size being underestimated:
        # - It doesn't factor in any group membership via SID history
        # - It doesn't factor in any shadow principal memberships
        $ADGroups = @(Get-ADGroup @CommonParams -SearchBase '' -LDAPFilter $LdapGroupsFilter) + $ADUserPrimaryGroup
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    $SIDHistory = @($ADUser.SIDHistory).Count
    $GroupsDomainLocal = @($ADGroups | Where-Object GroupScope -EQ 'DomainLocal').Count
    $GroupsGlobal = @($ADGroups | Where-Object GroupScope -EQ 'Global').Count
    $GroupsUniversalInside = @($ADGroups | Where-Object { $PSItem.GroupScope -eq 'Universal' -and $PSItem.SID.AccountDomainSid -eq $ADUser.SID.AccountDomainSid }).Count
    $GroupsUniversalOutside = @($ADGroups | Where-Object { $PSItem.GroupScope -eq 'Universal' -and $PSItem.SID.AccountDomainSid -ne $ADUser.SID.AccountDomainSid }).Count

    $TokenSizeBytes = $TicketOverheadBytes

    switch ($OperatingSystem) {
        'Windows Server 2012 (or later)' {
            $TokenSizeBytes += (40 * ($SIDHistory + $GroupsUniversalOutside)) + (8 * ($GroupsDomainLocal + $GroupsGlobal + $GroupsUniversalInside))
        }

        'Windows Server 2008 R2 (or earlier)' {
            $TokenSizeBytes += (40 * ($SIDHistory + $GroupsDomainLocal + $GroupsUniversalOutside)) + (8 * ($GroupsGlobal + $GroupsUniversalInside))
        }
    }

    if ($ADUser.TrustedForDelegation) {
        $TokenSizeBytes = $TokenSizeBytes * 2
    }

    $TokenSize = [PSCustomObject]@{
        SIDHistory           = $SIDHistory
        DomainLocal          = $GroupsDomainLocal
        Global               = $GroupsGlobal
        UniversalInside      = $GroupsUniversalInside
        UniversalOutside     = $GroupsUniversalOutside
        TrustedForDelegation = $ADUser.TrustedForDelegation
        TicketOverheadBytes  = $TicketOverheadBytes
        TokenSizeBytes       = $TokenSizeBytes
    }

    return $TokenSize
}

#endregion

#region Shadow security principals

# Add members to a shadow principal
Function Global:Add-ADShadowPrincipalMember {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('Void', 'Microsoft.ActiveDirectory.Management.ADObject[]')]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [String[]]$Members,

        [ValidateRange(300, 86400)]
        [UInt32]$Duration,

        [ValidateNotNullOrEmpty()]
        [String]$Server,

        [Switch]$PassThru
    )

    $CommonParams = @{ ErrorAction = 'Stop' }

    if ($Server) {
        $CommonParams['Server'] = $Server
    }

    try {
        $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer @CommonParams
        $ShadowPrincipal = Get-ADObject @CommonParams -Filter { CN -eq $Name } -SearchBase $ShadowPrincipalContainer -SearchScope 'Subtree'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    if (!$ShadowPrincipal) {
        $ExcMsg = "No shadow principal found for filter on CN: ${Name}"
        $ErrExc = [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ADShadowPrincipalNotFound', $ErrCat, $Name)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($ShadowPrincipal -is [Array]) {
        $ExcMsg = "Expected a single shadow principal but found $($ShadowPrincipal.Count) for filter on CN: ${Name}"
        $ErrExc = [Microsoft.ActiveDirectory.Management.ADIdentityResolutionException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ADMultipleShadowPrincipals', $ErrCat, $Name)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    foreach ($Member in $Members) {
        try {
            $User = Get-ADUser @CommonParams -Filter { CN -eq $Member }
        } catch {
            $PSCmdlet.WriteError($PSItem)
            continue
        }

        if (!$User) {
            $ExcMsg = "No AD user found for filter on CN: ${Member}"
            $ErrExc = [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ADUserNotFound', $ErrCat, $Member)
            $PSCmdlet.WriteError($ErrRec)
            continue
        }

        if ($User -is [Array]) {
            $ExcMsg = "Expected a single user but found $($User.Count) for filter on CN: ${Member}"
            $ErrExc = [Microsoft.ActiveDirectory.Management.ADIdentityResolutionException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ADMultipleUsers', $ErrCat, $Member)
            $PSCmdlet.WriteError($ErrRec)
            continue
        }

        if ($Duration) {
            $MemberValue = "<TTL=${Duration},$($User.DistinguishedName)>"
        } else {
            $MemberValue = $User.DistinguishedName
        }

        if ($PSCmdlet.ShouldProcess($Name, "Add $($User.UserPrincipalName) to shadow principal")) {
            try {
                Set-ADObject @CommonParams -Identity $ShadowPrincipal -Add @{ member = $MemberValue } -PassThru:$PassThru
            } catch { $PSCmdlet.WriteError($PSItem) }
        }
    }
}

# Retrieve the `DN` for the "Shadow Principal Configuration" container
Function Global:Get-ADShadowPrincipalContainer {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Server
    )

    try {
        if (!$Server) {
            $DomainController = Get-ADDomainController -Discover -NextClosestSite -ErrorAction 'Stop'
            $Server = $DomainController.HostName.Value
        }

        $RootDse = Get-ADRootDSE -Server $Server -ErrorAction 'Stop'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    return "CN=Shadow Principal Configuration,CN=Services,$($RootDse.configurationNamingContext)"
}

# Create a shadow principal
Function Global:New-ADShadowPrincipal {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('Void', 'Microsoft.ActiveDirectory.Management.ADObject')]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [Security.Principal.SecurityIdentifier]$SID,

        [ValidateNotNullOrEmpty()]
        [String]$Server,

        [Switch]$PassThru
    )

    $CommonParams = @{ ErrorAction = 'Stop' }

    if ($Server) {
        $CommonParams['Server'] = $Server
    }

    try {
        $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer @CommonParams
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    $SidByteArray = [Byte[]]::new($SID.BinaryLength)
    $SID.GetBinaryForm($SidByteArray, 0)

    $SpParams = @{
        Type            = 'msDS-ShadowPrincipal'
        Path            = $ShadowPrincipalContainer
        Name            = $Name
        OtherAttributes = @{
            'msDS-ShadowPrincipalSid' = $SidByteArray
        }
        PassThru        = $PassThru
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create shadow principal')) {
        try {
            New-ADObject @CommonParams @SpParams
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }
}

#endregion

Complete-DotFilesSection
