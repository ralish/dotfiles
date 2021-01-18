if ($DotFilesShowScriptEntry) { Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath) }

if (!(Test-IsWindows)) {
    return
}

try {
    if (!$DotFilesFastLoad) {
        Test-ModuleAvailable -Name ActiveDirectory
    }
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping import of Active Directory functions.')
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

        [ValidateRange("Positive")]
        [Int]$TicketOverheadBytes = 1200
    )

    if ($Username.Split('\').Count -ne 1) {
        if ($Username.Split('\').Count -gt 2) {
            throw 'Only a single backslash may be present in username.'
        }

        $Domain = $Username.Split('\')[0]
        $User = $Username.Split('\')[1]
    } elseif ($Username.Split('@').count -ne 1) {
        if ($Username.Split('@').Count -gt 2) {
            throw 'Only a single "@" sign may be present in username.'
        }

        $User = $Username.Split('@')[0]
        $Domain = $Username.Split('@')[1]
    } else {
        $User = $Username
        $Domain = $env:USERDOMAIN
    }

    try {
        $ADDomain = Get-ADDomain -Identity $Domain -ErrorAction Stop
    } catch {
        throw $_
    }

    try {
        $ADUser = Get-ADUser -Server $ADDomain.PDCEmulator -Identity $User -Properties SIDHistory, TrustedForDelegation -ErrorAction Stop
    } catch {
        throw $_
    }

    try {
        $ADGroups = Get-ADPrincipalGroupMembership -Server $ADDomain.PDCEmulator -Identity $User -ErrorAction Stop
    } catch {
        throw $_
    }

    $SIDHistory = $ADUser.$SIDHistory.Count
    $DomainLocal = @($ADGroups | Where-Object { $_.GroupScope -eq 'DomainLocal' }).Count
    $Global = @($ADGroups | Where-Object { $_.GroupScope -eq 'Global' }).Count
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
        $CommonParams = @{
            ErrorAction = 'Stop'
        }

        if ($Server) {
            $CommonParams.Add('Server', $Server)
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
            }

            'SchemaObject' {
                $SearchBase = $RootDse.schemaNamingContext
                $TypeName = 'Microsoft.ActiveDirectory.Management.ADObject.SchemaObject'
            }
        }

        $SearchFilters = @()
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Guid') {
            foreach ($ADGuid in $Guid) {
                switch ($Type) {
                    'ExtendedRight' {
                        $SearchFilters += '(&(objectClass=controlAccessRight)(rightsGuid={0}))' -f $ADGuid
                    }

                    'SchemaObject' {
                        $GuidOctetString = '\{0}' -f [String]::Join('\', ($ADGuid.ToByteArray() | ForEach-Object { $_.ToString('x2') }))
                        $SearchFilters += '(schemaIDGUID={0})' -f $GuidOctetString
                    }
                }
            }
        } else {
            switch ($Type) {
                'ExtendedRight' {
                    $SearchFilters += '(objectClass=controlAccessRight)'
                }

                'SchemaObject' {
                    $SearchFilters += '(objectClass=*)'
                }
            }
        }
    }

    End {
        $ADObjects = [Collections.ArrayList]::new()

        foreach ($SearchFilter in $SearchFilters) {
            $Results = Get-ADObject @CommonParams -SearchBase $SearchBase -LDAPFilter $SearchFilter -Properties *
            foreach ($ADObject in $Results) {
                $ADObject.PSObject.TypeNames.Insert(0, $TypeName)
                $null = $ADObjects.Add($ADObject)
            }
        }

        return $ADObjects
    }
}

#endregion

#region Shadow security principals

# Add members to a shadow principal
Function Add-ADShadowPrincipalMember {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [String[]]$Members,

        [ValidateRange(300, 86400)]
        [Int]$Duration
    )

    $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer
    $ShadowPrincipal = Get-ADObject -Filter { CN -eq $Name } -SearchBase $ShadowPrincipalContainer -SearchScope Subtree

    foreach ($Member in $Members) {
        $User = Get-ADUser -Filter { CN -eq $Member }

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

    try {
        $Dc = Get-ADDomainController -Discover -NextClosestSite -ErrorAction Stop
    } catch {
        throw $_
    }

    try {
        $RootDse = Get-ADRootDSE -Server $Dc.HostName.Value -ErrorAction Stop
    } catch {
        throw $_
    }

    $SpcDn = 'CN=Shadow Principal Configuration,CN=Services,{0}' -f $RootDse.configurationNamingContext

    return $SpcDn
}

# Create a shadow principal
Function New-ADShadowPrincipal {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [Security.Principal.SecurityIdentifier]$Sid
    )

    $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer

    $SidByteArray = [byte[]]::new($Sid.BinaryLength)
    $Sid.GetBinaryForm($SidByteArray, 0)

    New-ADObject -Type 'msDS-ShadowPrincipal' -Path $ShadowPrincipalContainer -Name $Name -OtherAttributes @{ 'msDS-ShadowPrincipalSid' = $SidByteArray }
}

#endregion
