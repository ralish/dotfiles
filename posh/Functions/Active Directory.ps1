$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Active Directory'
    Platform = 'Windows'
    Module   = 'ActiveDirectory'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Active Directory.format.ps1xml'))

#region Kerberos

# Estimate the Kerberos token size for a user
#
# Problems with Kerberos authentication when a user belongs to many groups
# https://learn.microsoft.com/en-au/troubleshoot/windows-server/windows-security/kerberos-authentication-problems-if-user-belongs-to-groups
Function Get-KerberosTokenSize {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        # Only the `DOMAIN\Username` format is supported (domain is optional)
        [Parameter(Mandatory)]
        [String]$Username,

        [ValidateSet('Windows Server 2008 R2 (or earlier)', 'Windows Server 2012 (or later)')]
        [String]$OperatingSystem = 'Windows Server 2012 (or later)',

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]$TicketOverheadBytes = 1200,

        [ValidateNotNullOrEmpty()]
        [String]$Server
    )

    Test-ModuleAvailable -Name 'ActiveDirectory'

    if ($Username.Split('\').Count -ge 2) {
        if ($Username.Split('\').Count -ne 2) {
            throw 'Expected only a single "\" character to be present in username.'
        }

        $Domain = $Username.Split('\')[0]
        $User = $Username.Split('\')[1]
    } else {
        $User = $Username
        $Domain = $env:USERDOMAIN
    }

    try {
        if ($Server) {
            $ADDomain = Get-ADDomain -Server $Server -Identity $Domain
        } else {
            $ADDomain = Get-ADDomain -Identity $Domain
            $Server = $ADDomain.PDCEmulator
        }

        $ADUser = Get-ADUser -Server $Server -Identity $User -Properties 'SIDHistory', 'TrustedForDelegation'

        # There's a bug in the `Get-ADPrincipalGroupMembership` cmdlet where it
        # returns a generic "An unspecified error has occurred" exception when
        # the request is for a user account with delegation disabled. The
        # workaround is to provide the `ResourceContextServer` parameter.
        $ADGroups = Get-ADPrincipalGroupMembership -Server $Server -ResourceContextServer $ADDomain.DNSRoot -Identity $User
    } catch { throw $_ }

    $SIDHistory = $ADUser.$SIDHistory.Count
    $DomainLocal = @($ADGroups | Where-Object GroupScope -EQ 'DomainLocal').Count
    $Global = @($ADGroups | Where-Object GroupScope -EQ 'Global').Count
    $UniversalInside = @($ADGroups | Where-Object { $_.GroupScope -eq 'Universal' -and $_.distinguishedName.EndsWith($ADDomain.DistinguishedName) }).Count
    $UniversalOutside = @($ADGroups | Where-Object { $_.GroupScope -eq 'Universal' -and !$_.distinguishedName.EndsWith($ADDomain.DistinguishedName) }).Count

    switch ($OperatingSystem) {
        'Windows Server 2012 (or later)' {
            $TokenSizeBytes = (40 * ($SIDHistory + $UniversalOutside)) + (8 * ($DomainLocal + $Global + $UniversalInside))
        }

        'Windows Server 2008 R2 (or earlier)' {
            $TokenSizeBytes = (40 * ($SIDHistory + $DomainLocal + $UniversalOutside)) + (8 * ($Global + $UniversalInside))
        }
    }

    if ($ADUser.TrustedForDelegation) {
        $TokenSizeBytes = $TokenSizeBytes * 2
    }

    $TokenSizeBytes += $TicketOverheadBytes

    $TokenSize = [PSCustomObject]@{
        SIDHistory           = $SIDHistory
        DomainLocal          = $DomainLocal
        Global               = $Global
        UniversalInside      = $UniversalInside
        UniversalOutside     = $UniversalOutside
        TrustedForDelegation = $ADUser.TrustedForDelegation
        TicketOverheadBytes  = $TicketOverheadBytes
        TokenSizeBytes       = $TokenSizeBytes
    }

    return $TokenSize
}

#endregion

#region Schema

# Resolve AD GUIDs corresponding to extended rights or schema objects
Function Resolve-ADGuid {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    [CmdletBinding(DefaultParameterSetName = 'Guid')]
    # The AD type may not be available at the time the function is sourced due
    # to lazy import of the `ActiveDirectory` module.
    #[OutputType([Void], [Microsoft.ActiveDirectory.Management.ADObject[]])]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('ExtendedRight', 'SchemaObject')]
        [String]$Type,

        [Parameter(ParameterSetName = 'Guid', Mandatory, ValueFromPipeline)]
        [Guid[]]$Guid,

        [Parameter(ParameterSetName = 'All')]
        [Switch]$All,

        [ValidateNotNullOrEmpty()]
        [String]$Server
    )

    Begin {
        Test-ModuleAvailable -Name 'ActiveDirectory'

        $CommonParams = @{}
        if ($Server) {
            $CommonParams['Server'] = $Server
        }

        try {
            $RootDse = Get-ADRootDSE @CommonParams
        } catch { throw $_ }

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

        Write-Verbose -Message ('Using search base: {0}' -f $SearchBase)

        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            $LDAPFilters = [Collections.Generic.List[String]]::new()
        }
    }

    Process {
        if ($PSCmdlet.ParameterSetName -ne 'Guid') { return }

        foreach ($ADGuid in $Guid) {
            switch ($Type) {
                'ExtendedRight' {
                    $LDAPFilters.Add('(rightsGuid={0})' -f $ADGuid)
                }

                'SchemaObject' {
                    $HexBytes = $ADGuid.ToByteArray() | ForEach-Object { $_.ToString('x2') }
                    $LDAPFilters.Add('(schemaIDGUID=\{0})' -f ($HexBytes -join '\'))
                }
            }
        }
    }

    End {
        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            $LDAPFilter = '(|{0})' -f ($LDAPFilters -join [String]::Empty)
        }

        Write-Verbose -Message ('Using LDAP filter: {0}' -f $LDAPFilter)
        try {
            $ADObjects = @(Get-ADObject @CommonParams -SearchBase $SearchBase -LDAPFilter $LDAPFilter -Properties *)
        } catch { throw $_ }

        foreach ($ADObject in $ADObjects) {
            $ADObject.PSObject.TypeNames.Insert(0, $TypeName)
        }

        return $ADObjects
    }
}

#endregion

#region Shadow security principals

# Add members to a shadow principal
Function Add-ADShadowPrincipalMember {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    [CmdletBinding(SupportsShouldProcess)]
    # The AD type may not be available at the time the function is sourced due
    # to lazy import of the `ActiveDirectory` module.
    #[OutputType([Void], [Microsoft.ActiveDirectory.Management.ADObject[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [String[]]$Members,

        [ValidateRange(300, 86400)]
        [Int]$Duration,

        [ValidateNotNullOrEmpty()]
        [String]$Server,

        [Switch]$PassThru
    )

    Test-ModuleAvailable -Name 'ActiveDirectory'

    $CommonParams = @{}
    if ($Server) {
        $CommonParams['Server'] = $Server
    }

    $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer @CommonParams

    try {
        $ShadowPrincipal = Get-ADObject @CommonParams -Filter { CN -eq $Name } -SearchBase $ShadowPrincipalContainer -SearchScope 'Subtree'
    } catch { throw $_ }

    if (!$ShadowPrincipal) {
        throw 'No shadow principal found for filter on CN: {0}' -f $Name
    }

    if ($ShadowPrincipal -is [Array]) {
        throw 'Expected a single shadow principal but found {0} for filter on CN: {1}' -f $ShadowPrincipal.Count, $Name
    }

    foreach ($Member in $Members) {
        try {
            $User = Get-ADUser @CommonParams -Filter { CN -eq $Member }
        } catch {
            Write-Error -Message $PSItem.Exception.Message
            continue
        }

        if (!$User) {
            Write-Error -Message ('No AD user found for filter on CN: {0}' -f $Member)
            continue
        }

        if ($User -is [Array]) {
            Write-Error -Message ('Expected a single user but found {0} for filter on CN: {1}' -f $User.Count, $Member)
            continue
        }

        if ($Duration) {
            $MemberValue = '<TTL={0},{1}>' -f $Duration, $User.DistinguishedName
        } else {
            $MemberValue = $User.DistinguishedName
        }

        try {
            Set-ADObject @CommonParams -Identity $ShadowPrincipal -Add @{ member = $MemberValue } -PassThru:$PassThru
        } catch { throw $_ }
    }
}

# Retrieve the `DN` for the "Shadow Principal Configuration" container
Function Get-ADShadowPrincipalContainer {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Server
    )

    Test-ModuleAvailable -Name 'ActiveDirectory'

    try {
        if (!$Server) {
            $DC = Get-ADDomainController -Discover -NextClosestSite
            $Server = $DC.HostName.Value
        }

        $RootDse = Get-ADRootDSE -Server $Server
    } catch { throw $_ }

    return 'CN=Shadow Principal Configuration,CN=Services,{0}' -f $RootDse.configurationNamingContext
}

# Create a shadow principal
Function New-ADShadowPrincipal {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    [CmdletBinding(SupportsShouldProcess)]
    # The AD type may not be available at the time the function is sourced due
    # to lazy import of the `ActiveDirectory` module.
    #[OutputType([Void], [Microsoft.ActiveDirectory.Management.ADObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [Security.Principal.SecurityIdentifier]$SID,

        [ValidateNotNullOrEmpty()]
        [String]$Server,

        [Switch]$PassThru
    )

    Test-ModuleAvailable -Name 'ActiveDirectory'

    $CommonParams = @{}
    if ($Server) {
        $CommonParams['Server'] = $Server
    }

    $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer @CommonParams

    $SidByteArray = [byte[]]::new($SID.BinaryLength)
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

    New-ADObject @CommonParams @SpParams
}

#endregion

Complete-DotFilesSection
