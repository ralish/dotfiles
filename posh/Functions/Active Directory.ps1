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

        [Parameter(ParameterSetName='Guid', ValueFromPipeline)]
        [Guid[]]$Guid,

        [Parameter(ParameterSetName='All')]
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
                        $GuidOctetString = '\{0}' -f [System.String]::Join('\', ($ADGuid.ToByteArray() | ForEach-Object { $_.ToString('x2') }))
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
        $ADObjects = @()

        foreach ($SearchFilter in $SearchFilters) {
            $ADObjects += Get-ADObject @CommonParams -SearchBase $SearchBase -LDAPFilter $SearchFilter -Properties *
        }

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
