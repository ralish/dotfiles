if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing PowerShell functions ...')

#region Internals

# Retrieve custom argument completers
# Via: https://gist.github.com/indented-automation/26c637fb530c4b168e62c72582534f5b
Function Get-ArgumentCompleter {
    [CmdletBinding()]
    Param(
        [Switch]$Native
    )

    $BindingFlags = [Reflection.BindingFlags]'NonPublic, Static'
    $LocalPipelineType = [PowerShell].Assembly.GetType('System.Management.Automation.Runspaces.LocalPipeline')
    $GetExecutionContextFromTLS = $LocalPipelineType.GetMethod('GetExecutionContextFromTLS', $BindingFlags)
    $InternalExecutionContext = $GetExecutionContextFromTLS.Invoke($null, $BindingFlags, $null, $null, $PSCulture) # DevSkim: ignore DS440000

    $BindingFlags = [Reflection.BindingFlags]'Instance, NonPublic'
    if ($Native) {
        $ArgumentCompletersPropertyName = 'NativeArgumentCompleters'
    } else {
        $ArgumentCompletersPropertyName = 'CustomArgumentCompleters'
    }
    $ArgumentCompletersProperty = $InternalExecutionContext.GetType().GetProperty($ArgumentCompletersPropertyName, $BindingFlags)

    $BindingFlags = [Reflection.BindingFlags]'GetProperty, Instance, NonPublic'
    $ArgumentCompleters = $ArgumentCompletersProperty.GetGetMethod($true).Invoke($InternalExecutionContext, $BindingFlags, $null, @(), $PSCulture)

    foreach ($Completer in $ArgumentCompleters.Keys) {
        $Name, $Parameter = $Completer.Split(':')

        [PSCustomObject]@{
            CommandName   = $Name
            ParameterName = $Parameter
            Definition    = $ArgumentCompleters[$Completer]
        }
    }
}

#endregion

#region Object handling

# Compare two hashtables
Function Compare-Hashtable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Reference,

        [Parameter(Mandatory)]
        [Hashtable]$Difference,

        [ValidateSet('Default', 'Insensitive', 'Sensitive')]
        [String]$CaseMatching = 'Default'
    )

    $Results = [Collections.ArrayList]::new()

    $AllKeys = ($Reference.Keys + $Difference.Keys) | Sort-Object -Unique
    foreach ($Key in $AllKeys) {
        $Result = [PSCustomObject]@{
            Key        = $Key
            Reference  = $null
            Difference = $null
        }

        if ($Reference.ContainsKey($Key) -and $Difference.ContainsKey($Key)) {
            $Identical = $false

            switch ($CaseMatching) {
                'Insensitive' {
                    if ($Reference[$Key] -ieq $Difference[$Key]) {
                        $Identical = $true
                    }
                }
                'Sensitive' {
                    if ($Reference[$Key] -ceq $Difference[$Key]) {
                        $Identical = $true
                    }
                }
                Default {
                    if ($Reference[$Key] -eq $Difference[$Key]) {
                        $Identical = $true
                    }
                }
            }

            if ($Identical) {
                continue
            }

            $Result.Reference = $Reference[$Key]
            $Result.Difference = $Difference[$Key]
        } elseif ($Reference.ContainsKey($Key)) {
            $Result.Reference = $Reference[$Key]
        } else {
            $Result.Difference = $Difference[$Key]
        }

        $null = $Results.Add($Result)
    }

    return $Results
}

# Compare the properties of two objects
# Via: https://blogs.technet.microsoft.com/janesays/2017/04/25/compare-all-properties-of-two-objects-in-windows-powershell/
Function Compare-ObjectProperties {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [PSObject]$ReferenceObject,

        [Parameter(Mandatory)]
        [PSObject]$DifferenceObject,

        [String[]]$IgnoredProperties
    )

    $ObjProps = @()
    $ObjProps += $ReferenceObject | Get-Member -MemberType Property, NoteProperty | Select-Object -ExpandProperty Name
    $ObjProps += $DifferenceObject | Get-Member -MemberType Property, NoteProperty | Select-Object -ExpandProperty Name
    $ObjProps = $ObjProps | Sort-Object | Select-Object -Unique

    if ($IgnoredProperties) {
        $ObjProps = $ObjProps | Where-Object { $_ -notin $IgnoredProperties }
    }

    $ObjDiffs = @()
    foreach ($Property in $ObjProps) {
        $Diff = Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Property $Property

        if ($Diff) {
            $DiffProps = @{
                PropertyName = $Property
                RefValue     = $Diff | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty $($Property)
                DiffValue    = $Diff | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty $($Property)
            }

            $ObjDiffs += New-Object -TypeName PSObject -Property $DiffProps
        }
    }

    if ($ObjDiffs) {
        return ($ObjDiffs | Select-Object -Property PropertyName, RefValue, DiffValue)
    }
}

# Compare the properties of multiple objects against a baseline
Function Compare-ObjectPropertiesMatrix {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [Object[]]$Objects,

        [ValidateNotNullOrEmpty()]
        [PSObject]$ReferenceObject,

        [String[]]$IgnoredProperties
    )

    Begin {
        $ComparedObjects = [Collections.ArrayList]::new()
        $DifferentProperties = [Collections.ArrayList]::new()

        $DiscoverReferenceObject = $false
        if (!$PSBoundParameters.ContainsKey('ReferenceObject')) {
            $DiscoverReferenceObject = $true
        }
    }

    Process {
        foreach ($Object in $Objects) {
            if ($Object -is [Array]) {
                Write-Warning -Message ('Skipping nested array.')
                continue
            }

            if ($DiscoverReferenceObject) {
                $ReferenceObject = $Object
                $DiscoverReferenceObject = $false
                continue
            }

            $Comparison = Compare-ObjectProperties -ReferenceObject $ReferenceObject -DifferenceObject $Object
            foreach ($PropertyName in $Comparison.PropertyName) {
                if ($DifferentProperties -notcontains $PropertyName) {
                    $null = $DifferentProperties.Add($PropertyName)
                }
            }
            $null = $ComparedObjects.Add($Object)
        }
    }

    End {
        if ($ComparedObjects.Count -eq 0) {
            throw 'No objects provided to compare against.'
        }

        if (!$PSBoundParameters.ContainsKey('ReferenceObject') -and !$ComparedObjects.Count -ge 2) {
            throw 'Objects collection must have at least two items.'
        }

        $FilteredProperties = @($DifferentProperties | Sort-Object -Unique | Where-Object { $_ -notin $IgnoredProperties })
        $ReferenceObject | Select-Object -Property $FilteredProperties
        $ComparedObjects | Select-Object -Property $FilteredProperties
    }
}

#endregion

#region Profile management

# Reload selected PowerShell profiles
Function Update-Profile {
    [CmdletBinding()]
    Param(
        [Switch]$AllUsersAllHosts,
        [Switch]$AllUsersCurrentHost,
        [Switch]$CurrentUserAllHosts,
        [Switch]$CurrentUserCurrentHost
    )

    if (!($PSBoundParameters.ContainsKey('AllUsersAllHosts') -or
            $PSBoundParameters.ContainsKey('AllUsersCurrentHost') -or
            $PSBoundParameters.ContainsKey('CurrentUserAllHosts') -or
            $PSBoundParameters.ContainsKey('CurrentUserCurrentHost'))) {
        $CurrentUserCurrentHost = $true
    }

    $ProfileTypes = 'AllUsersAllHosts', 'AllUsersCurrentHost', 'CurrentUserAllHosts', 'CurrentUserCurrentHost'
    foreach ($ProfileType in $ProfileTypes) {
        if (Get-Variable -Name $ProfileType -ValueOnly) {
            if (Test-Path -LiteralPath $profile.$ProfileType -PathType Leaf) {
                Write-Verbose -Message ('Sourcing {0} from: {1}' -f $ProfileType, $profile.$ProfileType)
                . $profile.$ProfileType
            } else {
                Write-Warning -Message ("Skipping {0} as it doesn't exist: {1}" -f $ProfileType, $profile.$ProfileType)
            }
        }
    }
}

#endregion

#region Shortcut functions

# Invoke Format-List selecting all properties
Function fla {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject]$InputObject,

        [Switch]$Force
    )

    Begin {
        $Objects = [Collections.ArrayList]::new()
    }

    Process {
        $null = $Objects.Add($InputObject)
    }

    End {
        $null = $PSBoundParameters.Remove('InputObject')
        $Objects | Format-List -Property * @PSBoundParameters
    }
}

# Invoke Format-Table selecting all properties
Function fta {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject]$InputObject,

        [Switch]$Force
    )

    Begin {
        $Objects = [Collections.ArrayList]::new()
    }

    Process {
        $null = $Objects.Add($InputObject)
    }

    End {
        $null = $PSBoundParameters.Remove('InputObject')
        $Objects | Format-Table -Property * @PSBoundParameters
    }
}

# Invoke Get-Help with -Detailed
Function ghd {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Detailed @PSBoundParameters
}

# Invoke Get-Help with -Examples
Function ghe {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Examples @PSBoundParameters
}

# Invoke Get-Help with -Full
Function ghf {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Full @PSBoundParameters
}

#endregion
