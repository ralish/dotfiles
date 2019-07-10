if (!(Test-IsWindows)) {
    return
}

# Load our custom formatting data
Update-FormatData -PrependPath (Join-Path -Path $PSScriptRoot -ChildPath 'Active Directory.format.ps1xml')

#region Helper functions
# Resolve various types of AD GUIDs
Function Resolve-ADGuid {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('ExtendedRight', 'SchemaObject')]
        [String]$Type,

        [Parameter(ValueFromPipeline)]
        [Guid[]]$Guid,

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
    }

    Process {
        foreach ($ADGuid in $Guid) {
            switch ($Type) {
                'ExtendedRight' {
                    $AdFilter = 'objectClass -eq "controlAccessRight"'
                    if ($Guid) {
                        # The single quoted variable is intentional! It's resolved
                        # at runtime by the ActiveDirectory Get-ADObject cmdlet.
                        $AdFilter = '{0} -and rightsGuid -eq $ADGuid' -f $AdFilter
                    }

                    $ADObject = Get-ADObject @CommonParams -SearchBase $RootDse.configurationNamingContext -Filter $AdFilter -Properties *
                    if ($ADObject) {
                        $ADObject.PSObject.TypeNames.Insert(0, 'Microsoft.ActiveDirectory.Management.ADObject.ControlAccessRight')
                        $ADObject
                    }
                }

                'SchemaObject' {
                    if ($Guid) {
                        # The single quoted variable is intentional! It's resolved
                        # at runtime by the ActiveDirectory Get-ADObject cmdlet.
                        $AdFilter = 'schemaIDGUID -eq $ADGuid'
                    } else {
                        $AdFilter = '*'
                    }

                    $ADObject = Get-ADObject @CommonParams -SearchBase $RootDse.schemaNamingContext -Filter $AdFilter -Properties *
                    if ($ADObject) {
                        $ADObject.PSObject.TypeNames.Insert(0, 'Microsoft.ActiveDirectory.Management.ADObject.SchemaObject')
                        $ADObject
                    }
                }
            }
        }
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
        [int]$Duration
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
        [System.Security.Principal.SecurityIdentifier]$Sid
    )

    $ShadowPrincipalContainer = Get-ADShadowPrincipalContainer

    $SidByteArray = New-Object -TypeName Byte[] -ArgumentList @($Sid.BinaryLength)
    $Sid.GetBinaryForm($SidByteArray, 0)

    New-ADObject -Type 'msDS-ShadowPrincipal' -Path $ShadowPrincipalContainer -Name $Name -OtherAttributes @{ 'msDS-ShadowPrincipalSid' = $SidByteArray }
}
#endregion
