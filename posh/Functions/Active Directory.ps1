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
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping import of Active Directory functions.')
    $Error.RemoveAt(0)
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing Active Directory functions ...')

# Load our custom formatting data
$null = $FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Active Directory.format.ps1xml'))

#region Kerberos

# Estimate the Kerberos token size for a user
# Reference: https://support.microsoft.com/kb/327825
# Inspired by: https://jacob.ludriks.com/2014/05/27/Getting-Kerberos-token-size-with-Powershell/
Function Get-KerberosTokenSize {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Username,

        [ValidateSet('Windows Server 2008 R2 (or earlier)', 'Windows Server 2012 (or later)')]
        [String]$OperatingSystem = 'Windows Server 2012 (or later)',

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]$TicketOverheadBytes = 1200,

        [ValidateNotNullOrEmpty()]
        [String]$Server
    )

    Test-ModuleAvailable -Name ActiveDirectory

    $CommonParams = @{
        ErrorAction = 'Stop'
    }

    if ($Username.Split('\').Count -ne 1) {
        if ($Username.Split('\').Count -gt 2) {
            Write-Error -Message 'Only a single backslash may be present in username.'
            return
        }

        $Domain = $Username.Split('\')[0]
        $User = $Username.Split('\')[1]
    } else {
        $User = $Username
        $Domain = $env:USERDOMAIN
    }

    try {
        if ($Server) {
            $ADDomain = Get-ADDomain @CommonParams -Identity $Domain -Server $Server
            $CommonParams['Server'] = $Server
        } else {
            $ADDomain = Get-ADDomain @CommonParams -Identity $Domain
            $CommonParams['Server'] = $ADDomain.PDCEmulator
        }
    } catch {
        throw $_
    }

    try {
        $ADUser = Get-ADUser @CommonParams -Identity $User -Properties SIDHistory, TrustedForDelegation
    } catch {
        throw $_
    }

    # There appears to be a bug in the Get-ADPrincipalGroupMembership cmdlet
    # where it may construct an incorrect LDAP path when an explicit AD server
    # is provided. What appears to be happening internally is the DC Locator
    # service is used to locate a DC which is populated into the LDAP path to
    # search. The connection will be made to the specified AD server, but if
    # the AD server returned by the DC Locator is different an error will be
    # returned by the AD server. This manifests on the client as a cryptic:
    # "An unspecified error has occurred" exception indicating a server error.
    try {
        $ADGroups = Get-ADPrincipalGroupMembership @CommonParams -Identity $User
    } catch {
        throw $_
    }

    $SIDHistory = $ADUser.$SIDHistory.Count
    $DomainLocal = @($ADGroups | Where-Object GroupScope -EQ 'DomainLocal').Count
    $Global = @($ADGroups | Where-Object GroupScope -EQ 'Global').Count
    $UniversalInside = @($ADGroups | Where-Object { $_.GroupScope -eq 'Universal' -and $_.distinguishedName.EndsWith($ADDomain.DistinguishedName) }).Count
    $UniversalOutside = @($ADGroups | Where-Object { $_.GroupScope -eq 'Universal' -and !$_.distinguishedName.EndsWith($ADDomain.DistinguishedName) }).Count

    if ($OperatingSystem -eq 'Windows Server 2012 (or later)') {
        $TokenSizeBytes = (40 * ($SIDHistory + $UniversalOutside)) + (8 * ($DomainLocal + $Global + $UniversalInside))
    } else {
        $TokenSizeBytes = (40 * ($SIDHistory + $DomainLocal + $UniversalOutside)) + (8 * ($Global + $UniversalInside))
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

# Resolve various types of AD GUIDs
Function Resolve-ADGuid {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('ExtendedRight', 'SchemaObject')]
        [String]$Type,

        [Parameter(ParameterSetName = 'Guid', ValueFromPipeline)]
        [Guid[]]$Guid,

        [Parameter(ParameterSetName = 'All')]
        [Switch]$All,

        [ValidateNotNullOrEmpty()]
        [String]$Server
    )

    Begin {
        Test-ModuleAvailable -Name ActiveDirectory

        $CommonParams = @{
            ErrorAction = 'Stop'
        }

        if ($Server) {
            $CommonParams['Server'] = $Server
        }

        try {
            $RootDse = Get-ADRootDSE @CommonParams
        } catch {
            throw $_
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

        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            $LDAPFilters = [Collections.Generic.List[String]]::new()
        }
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            foreach ($ADGuid in $Guid) {
                switch ($Type) {
                    'ExtendedRight' {
                        $null = $LDAPFilters.Add('(rightsGuid={0})' -f $ADGuid)
                    }

                    'SchemaObject' {
                        $HexBytes = $ADGuid.ToByteArray() | ForEach-Object { $_.ToString('x2') }
                        $null = $LDAPFilters.Add('(schemaIDGUID=\{0})' -f ($HexBytes -join '\'))
                    }
                }
            }
        }
    }

    End {
        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            $LDAPFilter = '(|{0})' -f ($LDAPFilters -join [String]::Empty)
        }

        Write-Debug -Message ('Retrieving AD objects using LDAP filter: {0}' -f $LDAPFilter)
        $ADObjects = Get-ADObject @CommonParams -SearchBase $SearchBase -LDAPFilter $LDAPFilter -Properties *

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
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [String[]]$Members,

        [ValidateRange(300, 86400)]
        [Int]$Duration
    )

    Test-ModuleAvailable -Name ActiveDirectory

    $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer
    $ShadowPrincipal = Get-ADObject -Filter { CN -eq $Name } -SearchBase $ShadowPrincipalContainer -SearchScope Subtree
    if (!$ShadowPrincipal) {
        Write-Error -Message ('No shadow principal found for filter on CN: {0}' -f $Name)
        return
    } elseif ($ShadowPrincipal -is [Array]) {
        Write-Error -Message ('Expected a single shadow principal but found {0} for filter on CN: {1}' -f $ShadowPrincipal.Count, $Name)
        return
    }

    foreach ($Member in $Members) {
        $User = Get-ADUser -Filter { CN -eq $Member }
        if (!$User) {
            Write-Error -Message ('No AD user found for filter on CN: {0}' -f $Member)
            continue
        } elseif ($User -is [Array]) {
            Write-Error -Message ('Expected a single user but found {0} for filter on CN: {1}' -f $User.Count, $Member)
            continue
        }

        if ($Duration) {
            $MemberValue = '<TTL={0},{1}>' -f $Duration, $User.DistinguishedName
        } else {
            $MemberValue = $User.DistinguishedName
        }

        Set-ADObject -Identity $ShadowPrincipal -Add @{ member = $MemberValue }
    }
}

# Retrieve the DN for the Shadow Principal Configuration container
Function Get-ADShadowPrincipalContainer {
    [CmdletBinding()]
    Param()

    Test-ModuleAvailable -Name ActiveDirectory

    try {
        $DC = Get-ADDomainController -Discover -NextClosestSite -ErrorAction Stop
    } catch {
        throw $_
    }

    try {
        $RootDse = Get-ADRootDSE -Server $DC.HostName.Value -ErrorAction Stop
    } catch {
        throw $_
    }

    return 'CN=Shadow Principal Configuration,CN=Services,{0}' -f $RootDse.configurationNamingContext
}

# Create a shadow principal
Function New-ADShadowPrincipal {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [Security.Principal.SecurityIdentifier]$Sid
    )

    Test-ModuleAvailable -Name ActiveDirectory

    $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer

    $SidByteArray = [byte[]]::new($Sid.BinaryLength)
    $Sid.GetBinaryForm($SidByteArray, 0)

    New-ADObject -Type msDS-ShadowPrincipal -Path $ShadowPrincipalContainer -Name $Name -OtherAttributes @{ 'msDS-ShadowPrincipalSid' = $SidByteArray }
}

#endregion
