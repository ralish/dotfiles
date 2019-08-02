if (!(Test-IsWindows)) {
    return
}

# Convert security descriptors between different formats
Function Convert-SecurityDescriptor {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='Binary', Mandatory)]
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

    $Files = Get-ChildItem -Path $Path -File -Recurse:$Recurse |
        Where-Object {
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
        $ACL = Get-ACL -LiteralPath $Directory.FullName
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

# Retrieve well-known security identifiers
Function Get-WellKnownSID {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='NTAuthority', Mandatory)]
        [ValidateSet('Anonymous', 'Authenticated Users', 'Batch', 'Claims Valid', 'Cloud Account Authentication', 'Compound Identity Present', 'Dialup', 'Digest Authentication', 'Enterprise Domain Controllers', 'IIS User', 'Interactive', 'Local Service', 'Local System', 'Microsoft Account Authentication', 'Network Service', 'Network', 'NTLM Authentication', 'Other Organization', 'Principal Self', 'Proxy', 'Remote Interactive Logon', 'Restricted', 'SChannel Authentication', 'Service', 'Terminal Server Users', 'This Organization Certificate', 'This Organization', 'User-mode Drivers', 'Write Restricted')]
        [String[]]$NTAuthority,

        [Parameter(ParameterSetName='Builtin', Mandatory)]
        [ValidateSet('Access Control Assistance Operators', 'Account Operators', 'Administrators', 'Backup Operators', 'Builtin', 'Certificate Service DCOM Access', 'Cryptographic Operators', 'Device Owners', 'Distributed COM Users', 'Event Log Readers', 'Guests', 'Hyper-V Administrators', 'IIS Users', 'Incoming Forest Trust Builders', 'Local account and member of Administrators group', 'Local account', 'Network Configuration Operators', 'Performance Log Users', 'Performance Monitor Users', 'Power Users', 'Pre-Windows 2000 Compatible Access', 'Print Operators', 'RDS Endpoint Servers', 'RDS Management Servers', 'RDS Remote Access Servers', 'Remote Desktop Users', 'Remote Management Users', 'Replicators', 'Server Operators', 'Storage Replica Administrators', 'System Managed Group', 'Terminal Server License Servers', 'Users', 'Windows Authorization Access Group')]
        [String[]]$Builtin,

        [Parameter(ParameterSetName='Domain', Mandatory)]
        [ValidateSet('Administrator', 'Allowed RODC Password Replication Group', 'Cert Publishers', 'Cloneable Domain Controllers', 'DefaultAccount', 'Denied RODC Password Replication Group', 'Domain Admins', 'Domain Computers', 'Domain Controllers', 'Domain Guests', 'Domain Users', 'Enterprise Admins', 'Enterprise Key Admins', 'Enterprise Read-only Domain Controllers', 'Group Policy Creator Owners', 'Guest', 'Key Admins', 'krbtgt', 'Protected Users', 'RAS and IAS Servers', 'Read-only Domain Controllers', 'Schema Admins', 'WDAGUtilityAccount')]
        [String[]]$Domain,

        [Parameter(ParameterSetName='Domain')]
        [ValidateNotNullOrEmpty()]
        [String]$DomainName,

        [Parameter(ParameterSetName='NullAuthority', Mandatory)]
        [ValidateSet('Nobody')]
        [String[]]$NullAuthority,

        [Parameter(ParameterSetName='WorldAuthority', Mandatory)]
        [ValidateSet('Everyone')]
        [String[]]$WorldAuthority,

        [Parameter(ParameterSetName='LocalAuthority', Mandatory)]
        [ValidateSet('Console Logon', 'Local')]
        [String[]]$LocalAuthority,

        [Parameter(ParameterSetName='CreatorAuthority', Mandatory)]
        [ValidateSet('Creator Group Server', 'Creator Group', 'Creator Owner Server', 'Creator Owner', 'Owner Rights')]
        [String[]]$CreatorAuthority,

        [Parameter(ParameterSetName='NTService', Mandatory)]
        [ValidateSet('All Services', 'NT Service')]
        [String[]]$NTService,

        [Parameter(ParameterSetName='NTVirtualMachine', Mandatory)]
        [ValidateSet('NT Virtual Machine', 'Virtual Machines')]
        [String[]]$NTVirtualMachine,

        [Parameter(ParameterSetName='NTTask', Mandatory)]
        [ValidateSet('NT Task')]
        [String[]]$NTTask,

        [Parameter(ParameterSetName='WindowManager', Mandatory)]
        [ValidateSet('Window Manager', 'Window Manager Group')]
        [String[]]$WindowManager,

        [Parameter(ParameterSetName='FontDriverHost', Mandatory)]
        [ValidateSet('Font Driver Host')]
        [String[]]$FontDriverHost,

        [Parameter(ParameterSetName='ApplicationPackageAuthority', Mandatory)]
        [ValidateSet('All Application Packages')]
        [String[]]$ApplicationPackageAuthority,

        [Parameter(ParameterSetName='MandatoryLabel', Mandatory)]
        [ValidateSet('High Mandatory Level', 'Low Mandatory Level', 'Medium Mandatory Level', 'Medium Plus Mandatory Level', 'Protected Process Mandatory Level', 'Secure Process Mandatory Level', 'System Mandatory Level', 'Untrusted Mandatory Level')]
        [String[]]$MandatoryLabel,

        [Parameter(ParameterSetName='IdentityAuthority', Mandatory)]
        [ValidateSet('Authentication authority asserted identity', 'Fresh public key identity', 'Key property attestation', 'Key property multi-factor authentication', 'Key trust identity', 'Service asserted identity')]
        [String[]]$IdentityAuthority
    )

    switch ($PSCmdlet.ParameterSetName) {
        NTAuthority {
            switch ($NTAuthority) {
                'Dialup'                                            { $SID = 'S-1-5-1' }
                'Network'                                           { $SID = 'S-1-5-2' }
                'Batch'                                             { $SID = 'S-1-5-3' }
                'Interactive'                                       { $SID = 'S-1-5-4' }
                'Service'                                           { $SID = 'S-1-5-6' }
                'Anonymous'                                         { $SID = 'S-1-5-7' }
                'Proxy'                                             { $SID = 'S-1-5-8' }
                'Enterprise Domain Controllers'                     { $SID = 'S-1-5-9' }
                'Principal Self'                                    { $SID = 'S-1-5-10' }
                'Authenticated Users'                               { $SID = 'S-1-5-11' }
                'Restricted'                                        { $SID = 'S-1-5-12' }
                'Terminal Server Users'                             { $SID = 'S-1-5-13' }
                'Remote Interactive Logon'                          { $SID = 'S-1-5-14' }
                'This Organization'                                 { $SID = 'S-1-5-15' }
                'IIS User'                                          { $SID = 'S-1-5-17' }
                'Local System'                                      { $SID = 'S-1-5-18' }
                'Local Service'                                     { $SID = 'S-1-5-19' }
                'Network Service'                                   { $SID = 'S-1-5-20' }
                'Compound Identity Present'                         { $SID = 'S-1-5-21-0-0-0-496' }
                'Claims Valid'                                      { $SID = 'S-1-5-21-0-0-0-497' }
                'Write Restricted'                                  { $SID = 'S-1-5-33' }
                'NTLM Authentication'                               { $SID = 'S-1-5-64-10' }
                'SChannel Authentication'                           { $SID = 'S-1-5-64-14' }
                'Digest Authentication'                             { $SID = 'S-1-5-64-21' }
                'Microsoft Account Authentication'                  { $SID = 'S-1-5-64-32' }
                'Cloud Account Authentication'                      { $SID = 'S-1-5-64-36' }
                'This Organization Certificate'                     { $SID = 'S-1-5-65-1' }
                'User-mode Drivers'                                 { $SID = 'S-1-5-84-0-0-0-0-0' }
                'Other Organization'                                { $SID = 'S-1-5-1000' }
            }
        }

        Builtin {
            switch ($Builtin) {
                'Builtin'                                           { $SID = 'S-1-5-32' }
                'Administrators'                                    { $SID = 'S-1-5-32-544' }
                'Users'                                             { $SID = 'S-1-5-32-545' }
                'Guests'                                            { $SID = 'S-1-5-32-546' }
                'Power Users'                                       { $SID = 'S-1-5-32-547' }
                'Account Operators'                                 { $SID = 'S-1-5-32-548' }
                'Server Operators'                                  { $SID = 'S-1-5-32-549' }
                'Print Operators'                                   { $SID = 'S-1-5-32-550' }
                'Backup Operators'                                  { $SID = 'S-1-5-32-551' }
                'Replicators'                                       { $SID = 'S-1-5-32-552' }
                'Pre-Windows 2000 Compatible Access'                { $SID = 'S-1-5-32-554' }
                'Remote Desktop Users'                              { $SID = 'S-1-5-32-555' }
                'Network Configuration Operators'                   { $SID = 'S-1-5-32-556' }
                'Incoming Forest Trust Builders'                    { $SID = 'S-1-5-32-557' }
                'Performance Monitor Users'                         { $SID = 'S-1-5-32-558' }
                'Performance Log Users'                             { $SID = 'S-1-5-32-559' }
                'Windows Authorization Access Group'                { $SID = 'S-1-5-32-560' }
                'Terminal Server License Servers'                   { $SID = 'S-1-5-32-561' }
                'Distributed COM Users'                             { $SID = 'S-1-5-32-562' }
                'IIS Users'                                         { $SID = 'S-1-5-32-568' }
                'Cryptographic Operators'                           { $SID = 'S-1-5-32-569' }
                'Event Log Readers'                                 { $SID = 'S-1-5-32-573' }
                'Certificate Service DCOM Access'                   { $SID = 'S-1-5-32-574' }
                'RDS Remote Access Servers'                         { $SID = 'S-1-5-32-575' }
                'RDS Endpoint Servers'                              { $SID = 'S-1-5-32-576' }
                'RDS Management Servers'                            { $SID = 'S-1-5-32-577' }
                'Hyper-V Administrators'                            { $SID = 'S-1-5-32-578' }
                'Access Control Assistance Operators'               { $SID = 'S-1-5-32-579' }
                'Remote Management Users'                           { $SID = 'S-1-5-32-580' }
                'System Managed Group'                              { $SID = 'S-1-5-32-581' }
                'Storage Replica Administrators'                    { $SID = 'S-1-5-32-582' }
                'Device Owners'                                     { $SID = 'S-1-5-32-583' }
                'Local account'                                     { $SID = 'S-1-5-113' }
                'Local account and member of Administrators group'  { $SID = 'S-1-5-114' }
            }
        }

        Domain {
            switch ($Domain) {
                'Enterprise Read-only Domain Controllers'           { $RID = '498' }
                'Administrator'                                     { $RID = '500' }
                'Guest'                                             { $RID = '501' }
                'krbtgt'                                            { $RID = '502' }
                'DefaultAccount'                                    { $RID = '503' }
                'WDAGUtilityAccount'                                { $RID = '504' }
                'Domain Admins'                                     { $RID = '512' }
                'Domain Users'                                      { $RID = '513' }
                'Domain Guests'                                     { $RID = '514' }
                'Domain Computers'                                  { $RID = '515' }
                'Domain Controllers'                                { $RID = '516' }
                'Cert Publishers'                                   { $RID = '517' }
                'Schema Admins'                                     { $RID = '518' }
                'Enterprise Admins'                                 { $RID = '519' }
                'Group Policy Creator Owners'                       { $RID = '520' }
                'Read-only Domain Controllers'                      { $RID = '521' }
                'Cloneable Domain Controllers'                      { $RID = '522' }
                'Protected Users'                                   { $RID = '525' }
                'Key Admins'                                        { $RID = '526' }
                'Enterprise Key Admins'                             { $RID = '527' }
                'RAS and IAS Servers'                               { $RID = '553' }
                'Allowed RODC Password Replication Group'           { $RID = '571' }
                'Denied RODC Password Replication Group'            { $RID = '572' }
            }

            if ($DomainName) {
                Test-ModuleAvailable -Name ActiveDirectory

                try {
                    $Dc = Get-ADDomainController -DomainName $DomainName -Discover -NextClosestSite -ErrorAction Stop
                } catch {
                    throw $_
                }

                try {
                    $RootDse = Get-ADRootDSE -Server $Dc.HostName.Value -ErrorAction Stop
                } catch {
                    throw $_
                }

                $DomainIdentifier = Get-ADObject -Server $Dc.HostName.Value -Identity $RootDse.defaultNamingContext -Properties objectSid
                $SID = '{0}-{1}' -f $DomainIdentifier.objectSid.Value, $RID
            } else {
                $LocalUsers = Get-LocalUser
                $SID = '{0}-{1}' -f $LocalUsers[0].SID.AccountDomainSid.Value, $RID
            }
        }

        NullAuthority {
            switch ($NullAuthority) {
                'Nobody'                                            { $SID = 'S-1-0-0' }
            }
        }

        WorldAuthority {
            switch ($WorldAuthority) {
                'Everyone'                                          { $SID = 'S-1-1-0' }
            }
        }

        LocalAuthority {
            switch ($LocalAuthority) {
                'Local'                                             { $SID = 'S-1-2-0' }
                'Console Logon'                                     { $SID = 'S-1-2-1' }
            }
        }

        CreatorAuthority {
            switch ($CreatorAuthority) {
                'Creator Owner'                                     { $SID = 'S-1-3-0' }
                'Creator Group'                                     { $SID = 'S-1-3-1' }
                'Creator Owner Server'                              { $SID = 'S-1-3-2' }
                'Creator Group Server'                              { $SID = 'S-1-3-3' }
                'Owner Rights'                                      { $SID = 'S-1-3-4' }
            }
        }

        NTService {
            switch ($NTService) {
                'NT Service'                                        { $SID = 'S-1-5-80' }
                'All Services'                                      { $SID = 'S-1-5-80-0' }
            }
        }

        NTVirtualMachine {
            switch ($NTVirtualMachine) {
                'NT Virtual Machine'                                { $SID = 'S-1-5-83' }
                'Virtual Machines'                                  { $SID = 'S-1-5-83-0' }
            }
        }

        NTTask {
            switch ($NTTask) {
                'NT Task'                                           { $SID = 'S-1-5-87' }
            }
        }

        WindowManager {
            switch ($WindowManager) {
                'Window Manager'                                    { $SID = 'S-1-5-90' }
                'Window Manager Group'                              { $SID = 'S-1-5-90-0' }
            }
        }

        FontDriverHost {
            switch ($FontDriverHost) {
                'Font Driver Host'                                  { $SID = 'S-1-5-96' }
            }
        }

        ApplicationPackageAuthority {
            switch ($ApplicationPackageAuthority) {
                'All Application Packages'                          { $SID = 'S-1-15-2-1' }
            }
        }

        MandatoryLabel {
            switch ($MandatoryLabel) {
                'Untrusted Mandatory Level'                         { $SID = 'S-1-16-0' }
                'Low Mandatory Level'                               { $SID = 'S-1-16-4096' }
                'Medium Mandatory Level'                            { $SID = 'S-1-16-8192' }
                'Medium Plus Mandatory Level'                       { $SID = 'S-1-16-8448' }
                'High Mandatory Level'                              { $SID = 'S-1-16-12288' }
                'System Mandatory Level'                            { $SID = 'S-1-16-16384' }
                'Protected Process Mandatory Level'                 { $SID = 'S-1-16-20480' }
                'Secure Process Mandatory Level'                    { $SID = 'S-1-16-28672' }
            }
        }

        IdentityAuthority {
            switch ($IdentityAuthority) {
                'Authentication authority asserted identity'        { $SID = 'S-1-18-1' }
                'Service asserted identity'                         { $SID = 'S-1-18-2' }
                'Fresh public key identity'                         { $SID = 'S-1-18-3' }
                'Key trust identity'                                { $SID = 'S-1-18-4' }
                'Key property multi-factor authentication'          { $SID = 'S-1-18-5' }
                'Key property attestation'                          { $SID = 'S-1-18-6' }
            }
        }
    }

    return [System.Security.Principal.SecurityIdentifier]$SID
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
