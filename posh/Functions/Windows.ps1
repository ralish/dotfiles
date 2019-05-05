if (!(Test-IsWindows)) {
    return
}

# Convert security descriptors between different formats
Function Convert-SecurityDescriptor {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='Binary', Mandatory, ValueFromPipeline)]
        [Byte[]]$BinarySD,

        [Parameter(ParameterSetName='SDDL', Mandatory, ValueFromPipeline)]
        [String]$SddlSD,

        [Parameter(ParameterSetName='WMI', Mandatory, ValueFromPipeline)]
        [Management.ManagementBaseObject]$WmiSD,

        [Parameter(Mandatory)]
        [ValidateSet('Binary', 'SDDL', 'WMI')]
        [String]$TargetType
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Binary' {
            if ($TargetType -eq 'SDDL') {
                return ([wmiclass]'Win32_SecurityDescriptorHelper').BinarySDToSDDL($BinarySD).SDDL
            } elseif ($TargetType -eq 'WMI') {
                return ([wmiclass]'Win32_SecurityDescriptorHelper').BinarySDToWin32SD($BinarySD).Descriptor
            }
        }

        'SDDL' {
            if ($TargetType -eq 'Binary') {
                return ([wmiclass]'Win32_SecurityDescriptorHelper').SDDLToBinarySD($SddlSD).BinarySD
            } elseif ($TargetType -eq 'WMI') {
                return ([wmiclass]'Win32_SecurityDescriptorHelper').SDDLToWin32SD($SddlSD).Descriptor
            }
        }

        'WMI' {
            if ($WmiSD.__CLASS -ne 'Win32_SecurityDescriptor') {
                throw ('Expected Win32_SecurityDescriptor instance but received: {0}' -f $WmiSD.__CLASS)
            }

            if ($TargetType -eq 'Binary') {
                return ([wmiclass]'Win32_SecurityDescriptorHelper').Win32SDToBinarySD($WmiSD).BinarySD
            } elseif ($TargetType -eq 'SDDL') {
                return ([wmiclass]'Win32_SecurityDescriptorHelper').Win32SDToSDDL($WmiSD).SDDL
            }
        }
    }

    throw 'Unable to convert security descriptor to same type as input.'
}

# Retrieve a persisted environment variable
Function Get-EnvironmentVariable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [ValidateSet('Machine', 'User')]
        [String]$Scope='User'
    )

    [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::$Scope)
}

# Retrieve files with a minimum number of hard links
Function Get-MultipleHardLinks {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseConsistentWhitespace', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$Path,

        [ValidateScript({$_ -gt 1})]
        [Int]$MinimumHardLinks=2,

        [Switch]$Recurse
    )

    $Files = Get-ChildItem -Path $Path -File -Recurse:$Recurse | Where-Object {
        $_.LinkType -eq 'HardLink' -and $_.Target.Count -ge ($MinimumHardLinks - 1)
    } | Add-Member -MemberType ScriptProperty -Name LinkCount -Value { $this.Target.Count + 1 } -Force

    return $Files
}

# Retrieve directories with non-inherited ACLs
Function Get-NonInheritedACL {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$User,

        [Switch]$Recurse
    )

    $Directories = Get-ChildItem -Path $Path -Directory -Recurse:$Recurse

    $ACLMatches = @()
    foreach ($Directory in $Directories) {
        $ACL = Get-ACL -Path $Directory.FullName
        $ACLNonInherited = $ACL.Access | Where-Object { $_.IsInherited -eq $false }

        if (!$ACLNonInherited) {
            continue
        }

        if ($PSBoundParameters.ContainsKey('User')) {
            if ($ACLNonInherited.IdentityReference -notcontains $User) {
                continue
            }
        }

        $ACLMatches += $Directory
    }

    return $ACLMatches
}

# Helper function to call MKLINK in cmd
Function mklink {
    & $env:ComSpec /c mklink $args
}

# Set a persisted environment variable
Function Set-EnvironmentVariable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseConsistentWhitespace', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(ValueFromPipeline)]
        [AllowEmptyString()]
        [String]$Value,

        [ValidateSet('Machine', 'User')]
        [String]$Scope='User',

        [ValidateSet('Overwrite', 'Append', 'Prepend')]
        [String]$Action='Overwrite'
    )

    if ($Action -in @('Append', 'Prepend')) {
        $CurrentValue = Get-EnvironmentVariable -Name $Name -Scope $Scope
    }

    switch ($Action) {
        'Overwrite' { $NewValue = $Value }
        'Append'    { $NewValue = '{0}{1}' -f $CurrentValue, $Value }
        'Prepend'   { $NewValue = '{0}{1}' -f $Value, $CurrentValue }
    }

    [Environment]::SetEnvironmentVariable($Name, $NewValue, [EnvironmentVariableTarget]::$Scope)
}

# Test if the user has Administrator privileges
Function Test-IsAdministrator {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    $User = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($User.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $true
    }
    return $false
}

# Watch an Event Log (similar to Unix "tail")
# Slightly improved from: http://stackoverflow.com/questions/15262196/powershell-tail-windows-event-log-is-it-possible
Function Watch-EventLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$EventLog
    )

    $IndexOld = (Get-EventLog -LogName $EventLog -Newest 1).Index
    do {
        Start-Sleep -Seconds 1
        $IndexNew = (Get-EventLog -LogName $EventLog -Newest 1).Index
        if ($IndexNew -ne $IndexOld) {
            Get-EventLog -LogName $EventLog -Newest ($IndexNew - $IndexOld) | Sort-Object -Property Index
            $IndexOld = $IndexNew
        }
    } while ($true)
}
