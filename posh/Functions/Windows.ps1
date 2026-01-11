$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Windows'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

#region Desktop

# Disable presentation mode
Function Disable-PresentationMode {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    & PresentationSettings.exe /stop
}

# Enable presentation mode
Function Enable-PresentationMode {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    & PresentationSettings.exe /start
}

#endregion

#region Environment variables

# Retrieve a persisted environment variable
Function Get-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([String], [Collections.Generic.List[PSCustomObject]])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [ValidateSet('Machine', 'Process', 'User')]
        [String]$Scope = 'Process'
    )

    if ($Name) {
        return [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::$Scope)
    }

    $EnvVarsRaw = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::$Scope)
    $EnvVars = [Collections.Generic.List[PSCustomObject]]::new()

    foreach ($EnvVarName in ($EnvVarsRaw.Keys | Sort-Object)) {
        $EnvVar = [PSCustomObject]@{
            Name  = $EnvVarName
            Value = $EnvVarsRaw[$EnvVarName]
        }

        $EnvVars.Add($EnvVar)
    }

    return $EnvVars.ToArray()
}

# Set a persisted environment variable
Function Set-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(ValueFromPipeline)]
        [AllowEmptyString()]
        [String]$Value,

        [ValidateSet('Machine', 'User')]
        [String]$Scope = 'User',

        [ValidateSet('Overwrite', 'Append', 'Prepend')]
        [String]$Action = 'Overwrite'
    )

    Process {
        if ($Action -in 'Append', 'Prepend') {
            $CurrentValue = Get-EnvironmentVariable -Name $Name -Scope $Scope
        }

        switch ($Action) {
            'Overwrite' { $NewValue = $Value }
            'Append' { $NewValue = '{0}{1}' -f $CurrentValue, $Value }
            'Prepend' { $NewValue = '{0}{1}' -f $Value, $CurrentValue }
        }

        [Environment]::SetEnvironmentVariable($Name, $NewValue, [EnvironmentVariableTarget]::$Scope)
    }
}

#endregion

#region Event logs

# dmesg for Windows!
Function dmesg {
    [OutputType([Void], [Diagnostics.Eventing.Reader.EventLogRecord[]], [String[]])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$ComputerName
    )

    $Filter = @(
        '*-Kernel-*'
        '*-TPM-*'
        '*-FilterManager'
        '*-HAL'
        '*-Hypervisor'
        '*-IsolatedUserMode'
        '*-Ntfs'
        '*-Wininit'
        '*-Winlogon'
        'TPM'
        'Win32k'
    )

    Find-WinEvent -Filter $Filter @PSBoundParameters @args
}

# Find events by filtering against logs and providers
Function Find-WinEvent {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([Void], [Diagnostics.Eventing.Reader.EventLogRecord[]], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Filter,

        [ValidateNotNullOrEmpty()]
        [DateTime]$StartTime,

        [Parameter(ParameterSetName = 'SeverityLevel', Mandatory)]
        [ValidateSet('Any', 'Critical', 'Error', 'Warning', 'Info', 'Verbose')]
        [String[]]$SeverityLevels,

        [Parameter(ParameterSetName = 'MinSeverity', Mandatory)]
        [ValidateSet('Any', 'Critical', 'Error', 'Warning', 'Info', 'Verbose')]
        [String]$MinSeverityLevel,

        [ValidateSet('EventLogRecord', 'PlainText', 'PlainTextMinimal')]
        [ValidateNotNullOrEmpty()]
        [String]$OutputFormat = 'EventLogRecord',

        [String[]]$ExcludedLogs = @(
            'Microsoft-Windows-CAPI2/Operational'
            'Microsoft-Windows-Hyper-V-VmSwitch-Operational'
            'PowerShellCore/Operational'
            'Security'
        ),

        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,

        [Switch]$Force
    )

    if (!(Test-IsAdministrator)) {
        Write-Warning -Message 'Some event logs may be inaccessible without administrator privileges.'
    }

    $WinEvents = [Collections.Generic.List[Diagnostics.Eventing.Reader.EventLogRecord]]::new()
    $EventLogs = [Collections.Generic.List[Diagnostics.Eventing.Reader.EventLogConfiguration]]::new()
    $SkippedLogs = [Collections.Generic.List[String]]::new()
    $ProviderLogs = @{}

    $CommonParams = @{}
    if ($ComputerName) {
        $CommonParams['ComputerName'] = $ComputerName
    }

    # EventLevel Enum
    # https://learn.microsoft.com/en-au/dotnet/api/system.diagnostics.tracing.eventlevel
    $EventLevelToInt = @{
        Any      = 0
        Critical = 1
        Error    = 2
        Warning  = 3
        Info     = 4
        Verbose  = 5
    }

    $EventLevelToName = @(
        'Any'
        'Critical'
        'Error'
        'Warning'
        'Info'
        'Verbose'
    )

    # Default to boot time as start time
    if (!$StartTime) {
        $StartTime = (Get-CimInstance @CommonParams -ClassName 'Win32_OperatingSystem').LastBootUpTime
    }

    # Configure event severity filtering
    if ($PSCmdlet.ParameterSetName -eq 'SeverityLevel' -and $SeverityLevels -notcontains 'Any') {
        $EventLevels = [Collections.Generic.List[Int]]::new()
        foreach ($Severity in $SeverityLevel) {
            $EventLevels.Add($EventLevelToInt[$Severity])
        }
    } elseif ($PSCmdlet.ParameterSetName -eq 'MinSeverity' -and $SeverityLevel -ne 'Any') {
        $EventLevels = 0..$EventLevelToInt[$MinSeverity]
    }

    # Retrieve matching event logs
    $EventLogsToAdd = Get-WinEvent @CommonParams -ListLog $Filter -Force:$Force -ErrorAction Ignore | Where-Object {
        # Explicitly excluded logs
        $_.LogName -notin $ExcludedLogs -and
        # No records (must test both!)
        $_.RecordCount -ne 0 -and
        $null -ne $_.RecordCount -and
        # Written to since start time
        $_.LastWriteTime -ge $StartTime
    }

    # Add matched event logs to array
    foreach ($Log in $EventLogsToAdd) {
        $EventLogs.Add($Log)
    }

    # Retrieve matching event providers. For each event provider, record which
    # event log(s) it outputs to. We'll later retrieve events from these log(s)
    # filtered by the event provider. Exclude any logs which match the filter,
    # as we'll retrieve all events from these logs without any provider filter.
    foreach ($Provider in (Get-WinEvent @CommonParams -ListProvider $Filter -ErrorAction Ignore)) {
        $LogLinks = $Provider.LogLinks | Where-Object LogName -NotIn $ExcludedLogs

        foreach ($Link in $LogLinks) {
            $LogName = $Link.LogName

            $LogFiltered = $false
            foreach ($Entry in $Filter) {
                if ($LogName -like $Entry) {
                    $LogFiltered = $true
                    break
                }
            }

            # Log already included by log filter
            if ($LogFiltered) {
                continue
            }

            # Log previously enumerated and inaccessible or irrelevant
            if ($SkippedLogs -contains $LogName) {
                continue
            }

            if (!$ProviderLogs.ContainsKey($LogName)) {
                try {
                    $Log = Get-WinEvent @CommonParams -ListLog $LogName -Force:$Force -ErrorAction Stop
                } catch {
                    Write-Error -Message $_.Exception.Message
                    $SkippedLogs.Add($LogName)
                    continue
                }

                # No records or not written to since start time
                if ($Log.RecordCount -eq 0 -or $null -eq $Log.RecordCount -or $Log.LastWriteTime -lt $StartTime) {
                    $SkippedLogs.Add($LogName)
                    continue
                }

                $EventLogs.Add($Log)
                $ProviderLogs[$LogName] = [Collections.Generic.List[String]]::new()
            }

            $ProviderLogs[$LogName].Add($Provider.Name)
        }
    }

    if ($EventLogs.Count -eq 0) {
        throw 'No event logs or providers matched the filter.'
    }

    $WriteProgressParams = @{
        Activity = 'Retrieving Windows event logs'
    }

    # Retrieve all the events matching the filter
    for ($Idx = 0; $Idx -lt $EventLogs.Count; $Idx++) {
        $EventLog = $EventLogs[$Idx]
        $LogName = $EventLog.LogName

        Write-Progress @WriteProgressParams -Status $LogName -PercentComplete ($Idx / $EventLogs.Count * 100)

        $EventFilter = @{
            LogName   = $LogName
            StartTime = $StartTime
        }

        if ($ProviderLogs.ContainsKey($LogName)) {
            $EventFilter['ProviderName'] = $ProviderLogs[$LogName].ToArray()
        }

        if ($EventLevels) {
            $EventFilter['Level'] = $EventLevels
        }

        $EventParams = @{
            FilterHashtable = $EventFilter
            Oldest          = $false
        }

        # Analytical & Debug logs must be read in forward chronological order
        if ($EventLog.LogType -in 'Analytical', 'Debug') {
            $EventParams['Oldest'] = $true
        }

        try {
            $FoundEvents = Get-WinEvent @CommonParams @EventParams -ErrorAction Stop
            foreach ($WinEvent in $FoundEvents) {
                $WinEvents.Add($WinEvent)
            }
        } catch {
            $Ex = $_
            switch -Regex ($_.FullyQualifiedErrorId) {
                '^NoMatchingEventsFound,' { continue }
                default {
                    Write-Warning -Message $Ex.Exception.Message
                    continue
                }
            }
        }

        $LogsDone++
    }

    Write-Progress @WriteProgressParams -Completed

    $SortedEvents = $WinEvents | Sort-Object -Property 'TimeCreated'

    if ($OutputFormat -eq 'EventLogRecord') {
        return $SortedEvents
    }

    $WinEvents = [Collections.Generic.List[String]]::new()
    $DateFormat = 'yyyy/MM/dd hh:mm:ss tt'
    $StringSplitOptions = [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
    $PrefixWhitespace = ' ' * ('[{0}] {1,-8} -> ' -f (Get-Date).ToString($DateFormat), $EventLevelToName[0]).Length
    $MultilinePrefix = '{0}{1}' -f [Environment]::NewLine, $PrefixWhitespace

    foreach ($WinEvent in $SortedEvents) {
        $Time = $WinEvent.TimeCreated.ToString($DateFormat)
        $Level = $EventLevelToName[$WinEvent.Level].ToUpper()
        $Provider = $WinEvent.ProviderName
        $Message = $WinEvent.Message

        $ReplaceChars = [Char[]]@(
            # Left-to-right mark
            0x200e
        )

        foreach ($Char in $ReplaceChars) {
            $Message = $Message.Replace([String]$Char, [String]::Empty)
        }

        if ($WinEvent.Message) {
            $Message = $Message.Split("`r`n", $StringSplitOptions).Split("`n", $StringSplitOptions)
        } else {
            $Message = [String]::Empty
        }

        if ($OutputFormat -eq 'PlainText') {
            $Text = '[{0}] {1,-8} -> {2}{3}{4}' -f $Time, $Level, $Provider, $MultilinePrefix, ($Message -join $MultilinePrefix)
        } else {
            $Text = '[{0}] {1,-8} -> {2}' -f $Time, $Level, ($Message -join $MultilinePrefix)
        }

        $WinEvents.Add($Text)
    }

    return $WinEvents.ToArray()
}

# Watch an Event Log (similar to Unix "tail")
# Slightly improved from: https://stackoverflow.com/a/15262376/8787985
Function Watch-EventLog {
    [CmdletBinding()]
    [OutputType([Void], [Diagnostics.Eventing.Reader.EventLogRecord[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$LogName
    )

    $IndexOld = (Get-WinEvent -LogName $LogName -MaxEvents 1).RecordId
    do {
        Start-Sleep -Seconds 1
        $IndexNew = (Get-WinEvent -LogName $LogName -MaxEvents 1).RecordId
        if ($IndexNew -ne $IndexOld) {
            Get-WinEvent -LogName $LogName -MaxEvents ($IndexNew - $IndexOld) | Sort-Object -Property 'RecordId'
            $IndexOld = $IndexNew
        }
    } while ($true)
}

#endregion

#region Filesystem

# Retrieve files with a minimum number of hard links
Function Get-MultipleHardLinks {
    [CmdletBinding()]
    [OutputType([Void], [IO.FileInfo[]])]
    Param(
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$Path,

        [ValidateScript( { $_ -gt 1 } )]
        [Int]$MinimumHardLinks = 2,

        [Switch]$Recurse,
        [Switch]$Force
    )

    $Files = Get-ChildItem -Path $Path -File -Recurse:$Recurse -Force:$Force |
        Where-Object {
            $_.LinkType -eq 'HardLink' -and $_.Target.Count -ge ($MinimumHardLinks - 1)
        } | Add-Member -MemberType ScriptProperty -Name 'LinkCount' -Value { $this.Target.Count + 1 } -Force -PassThru

    return $Files
}

# Retrieve directories with non-inherited ACLs
Function Get-NonInheritedACL {
    [CmdletBinding()]
    [OutputType([Void], [IO.DirectoryInfo[]])]
    Param(
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$User,

        [Switch]$Recurse,
        [Switch]$Force
    )

    $Directories = Get-ChildItem -Path $Path -Directory -Recurse:$Recurse -Force:$Force

    $ACLMatches = [Collections.Generic.List[IO.DirectoryInfo]]::new()
    foreach ($Directory in $Directories) {
        $ACL = Get-Acl -LiteralPath $Directory.FullName
        $ACLNonInherited = $ACL.Access | Where-Object { $_.IsInherited -eq $false }

        if (!$ACLNonInherited) {
            continue
        }

        if ($User) {
            if ($ACLNonInherited.IdentityReference -notcontains $User) {
                continue
            }
        }

        $ACLMatches.Add($Directory)
    }

    return $ACLMatches.ToArray()
}

# Helper function to call MKLINK in cmd
Function mklink {
    [OutputType([String])]
    Param()

    & $env:ComSpec /c mklink $args
}

#endregion

#region Networking

# Open the hosts file for editing
Function Edit-Hosts {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $StartProcessParams = @{
        FilePath     = 'notepad.exe'
        ArgumentList = '{0}\System32\drivers\etc\hosts' -f $env:SystemRoot
    }

    if (!(Test-IsAdministrator)) {
        $StartProcessParams.Add('Verb', 'RunAs')
    }

    Start-Process @StartProcessParams
}

# Restore connections to mapped network drives
Function Restore-MappedNetworkDrives {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $MappedDrives = Get-SmbMapping | Where-Object Status -EQ 'Unavailable'
    foreach ($MappedDrive in $MappedDrives) {
        Write-Verbose -Message ('Restoring mapped network drive: {0}' -f $MappedDrive.LocalPath)
        try {
            $null = New-SmbMapping -LocalPath $MappedDrive.LocalPath -RemotePath $MappedDrive.RemotePath -Persistent $true
        } catch {
            throw 'Failed to restore mapped network drive: {0}' -f $MappedDrive.LocalPath
        }
    }
}

#endregion

#region Registry

# Search the registry
Function Search-Registry {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([Void], [PSCustomObject[]], ParameterSetName = 'Default')]
    [OutputType([Void], ParameterSetName = 'Recursion')]
    Param(
        [Parameter(Mandatory, ParameterSetName = 'Default')]
        [ValidateSet('HKCC', 'HKCR', 'HKCU', 'HKLM', 'HKPD', 'HKU')]
        [String]$Hive,

        [Parameter(ParameterSetName = 'Default')]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$SimpleMatch,

        [ValidateSet('Keys', 'Values', 'Data')]
        [ValidateNotNullOrEmpty()]
        [String[]]$Types = @('Keys', 'Values', 'Data'),

        [Parameter(ParameterSetName = 'Default')]
        [Switch]$NoRecurse,

        [Parameter(Mandatory, ParameterSetName = 'Recursion')]
        [Microsoft.Win32.RegistryKey]$ParentKey,

        [Parameter(Mandatory, ParameterSetName = 'Recursion')]
        [String]$SubKeyName,

        [Parameter(Mandatory, ParameterSetName = 'Recursion')]
        [AllowEmptyCollection()]
        [Collections.Generic.List[PSCustomObject]]$Results
    )

    if ($PSCmdlet.ParameterSetName -eq 'Default') {
        switch ($Hive) {
            'HKCC' { $RegHive = [Microsoft.Win32.Registry]::CurrentConfig }
            'HKCR' { $RegHive = [Microsoft.Win32.Registry]::ClassesRoot }
            'HKCU' { $RegHive = [Microsoft.Win32.Registry]::CurrentUser }
            'HKLM' { $RegHive = [Microsoft.Win32.Registry]::LocalMachine }
            'HKPD' { $RegHive = [Microsoft.Win32.Registry]::PerformanceData }
            'HKU' { $RegHive = [Microsoft.Win32.Registry]::Users }
        }

        $RegKeys = [Collections.Generic.List[Microsoft.Win32.RegistryKey]]::new()
        $RegKeys.Add($RegHive)

        $DirSepChar = [IO.Path]::DirectorySeparatorChar
        $OpenSubKeyFailed = $false
        $SubKeys = $Path.Split($DirSepChar)

        foreach ($SubKey in $SubKeys) {
            try {
                $RegKey = $RegKeys[-1].OpenSubKey($SubKey)
                if (!$RegKey) {
                    $OpenSubKeyFailed = $true
                }
            } catch {
                $OpenSubKeyFailed = $true
            }

            if ($OpenSubKeyFailed) {
                $RegPath = '{0}{1}{2}' -f $SubKeys[-1].Name, $DirSepChar, $SubKeys[$RegKeys.Count - 1]
                Write-Error -Message ('Failed to open registry key: {0}' -f $RegPath)
                break
            }

            $RegKeys.Add($RegKey)
        }

        if ($OpenSubKeyFailed) {
            for ($i = $RegKeys.Count - 1; $i -ne 0; $i--) {
                $RegKeys[$i].Close()
            }

            return
        }

        $RegistryKey = $RegKeys[-1]
        $Results = [Collections.Generic.List[PSCustomObject]]::new()
    } else {
        $OpenSubKeyFailed = $false

        try {
            $RegistryKey = $ParentKey.OpenSubKey($SubKeyName)
            if (!$RegistryKey) {
                $OpenSubKeyFailed = $true
            }
        } catch {
            $OpenSubKeyFailed = $true
        }

        if ($OpenSubKeyFailed) {
            $RegPath = '{0}{1}{2}' -f $ParentKey.Name, [IO.Path]::DirectorySeparatorChar, $SubKeyName
            Write-Verbose -Message ('Failed to open registry key: {0}' -f $RegPath)
            return
        }

        $WriteProgressParams = @{
            Activity = 'Searching registry for simple match: {0}' -f $SimpleMatch
            Status   = $RegistryKey.Name
        }

        Write-Progress @WriteProgressParams
    }

    $Recurse = $false
    if ($PSCmdlet.ParameterSetName -eq 'Recursion' -or !$NoRecurse) {
        $Recurse = $true

        $SearchParams = @{
            SimpleMatch = $SimpleMatch
            Types       = $Types
            ParentKey   = $RegistryKey
            SubKeyName  = $null
            Results     = $Results
        }
    }

    if ($Types -contains 'Keys' -or $Recurse) {
        $SubKeyNames = $RegistryKey.GetSubKeyNames()

        foreach ($SubKeyName in $SubKeyNames) {
            $SubKeyPath = Join-Path -Path $RegistryKey.Name -ChildPath $SubKeyName

            if ($Types -contains 'Keys') {
                if ($SubKeyName -like $SimpleMatch) {
                    $Result = [PSCustomObject]@{
                        Key       = $SubKeyPath
                        MatchType = 'Key'
                        ValueName = $null
                        ValueData = $null
                    }

                    $Results.Add($Result)
                }
            }

            if ($Recurse) {
                $SearchParams.SubKeyName = $SubKeyName
                Search-Registry @SearchParams
            }
        }
    }

    if ($Types -contains 'Values' -or $Types -contains 'Data') {
        $ValueNames = $RegistryKey.GetValueNames()

        foreach ($ValueName in $ValueNames) {
            if ($Types -contains 'Values') {
                if ($ValueName -like $SimpleMatch) {
                    $Result = [PSCustomObject]@{
                        Key       = $RegistryKey.Name
                        MatchType = 'Value'
                        ValueName = $ValueName
                        ValueData = $null
                    }

                    $Results.Add($Result)
                }
            }

            if ($Types -contains 'Data') {
                $ValueData = $RegistryKey.GetValue($ValueName)

                if ($ValueData -like $SimpleMatch) {
                    $Result = [PSCustomObject]@{
                        Key       = $RegistryKey.Name
                        MatchType = 'Data'
                        ValueName = $ValueName
                        ValueData = $ValueData
                    }

                    $Results.Add($Result)
                }
            }
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'Recursion') {
        $RegistryKey.Close()
        return
    }

    for ($i = $RegKeys.Count - 1; $i -ne 0; $i--) {
        $RegKeys[$i].Close()
    }

    if ($Results.Count -gt 0) {
        return $Results.ToArray()
    }
}

#endregion

#region Remote Desktop Connection

# Update RDC default configuration
Function Update-RdcDefaultConfig {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $RdcDir = Join-Path -Path $DotFilesPath -ChildPath 'mstsc'
    $RdcTemplateFile = Join-Path -Path $RdcDir -ChildPath 'Template.ini'
    $RdcDefaultFile = Join-Path -Path $RdcDir -ChildPath 'Default.rdp'

    $RdcDefaultSettings = Get-Content -LiteralPath $RdcTemplateFile |
        # Exclude comments and blank lines
        Where-Object { $_ -match '^[a-z]' } |
        # RDC always lowercases setting names
        ForEach-Object { $_.ToLower() }

    # Encoding: UTF-16LE
    # Arguments: bigEndian, byteOrderMark
    $Encoder = [Text.UnicodeEncoding]::new($false, $true)

    # We do this slightly convoluted dance to handle the case where the file
    # already exists and has the Hidden and/or System attributes.
    try {
        $FileStream = [IO.File]::Open($RdcDefaultFile, [IO.FileMode]::OpenOrCreate)

        try {
            # Arguments: stream, encoding, bufferSize, leaveOpen
            $StreamWriter = [IO.StreamWriter]::new($FileStream, $Encoder, 1024, $true)

            foreach ($Line in $RdcDefaultSettings) {
                $StreamWriter.WriteLine($Line)
            }

            $StreamWriter.Flush()
        } finally {
            $StreamWriter.Dispose()
        }

        # Truncate any trailing data if the file already existed
        $FileStream.SetLength($FileStream.Position)
    } finally {
        $FileStream.Dispose()
    }

    # Match what RDC sets
    $RdcDefaultFileAttributes = [IO.FileAttributes]::Archive + [IO.FileAttributes]::Hidden + [IO.FileAttributes]::System
    [IO.File]::SetAttributes($RdcDefaultFile, $RdcDefaultFileAttributes)
}

#endregion

#region Security

# Convert security descriptors between different formats
Function Convert-SecurityDescriptor {
    [CmdletBinding()]
    [OutputType([Void], [String], [Management.ManagementBaseObject], ParameterSetName = 'Binary')]
    [OutputType([Void], [Byte[]], [Management.ManagementBaseObject], ParameterSetName = 'SDDL')]
    [OutputType([Void], [Byte[]], [String], ParameterSetName = 'WMI')]
    Param(
        [Parameter(ParameterSetName = 'Binary', Mandatory)]
        [Byte[]]$BinarySD,

        [Parameter(ParameterSetName = 'SDDL', Mandatory, ValueFromPipeline)]
        [String]$SddlSD,

        [Parameter(ParameterSetName = 'WMI', Mandatory, ValueFromPipeline)]
        [Management.ManagementBaseObject]$WmiSD,

        [Parameter(Mandatory)]
        [ValidateSet('Binary', 'SDDL', 'WMI')]
        [String]$TargetType
    )

    Process {
        switch ($PSCmdlet.ParameterSetName) {
            'Binary' {
                if ($TargetType -eq 'SDDL') {
                    return ([WmiClass]'Win32_SecurityDescriptorHelper').BinarySDToSDDL($BinarySD).SDDL
                } elseif ($TargetType -eq 'WMI') {
                    return ([WmiClass]'Win32_SecurityDescriptorHelper').BinarySDToWin32SD($BinarySD).Descriptor
                }
            }

            'SDDL' {
                if ($TargetType -eq 'Binary') {
                    return ([WmiClass]'Win32_SecurityDescriptorHelper').SDDLToBinarySD($SddlSD).BinarySD
                } elseif ($TargetType -eq 'WMI') {
                    return ([WmiClass]'Win32_SecurityDescriptorHelper').SDDLToWin32SD($SddlSD).Descriptor
                }
            }

            'WMI' {
                if ($WmiSD.__CLASS -ne 'Win32_SecurityDescriptor') {
                    throw 'Expected Win32_SecurityDescriptor instance but received: {0}' -f $WmiSD.__CLASS
                }

                if ($TargetType -eq 'Binary') {
                    return ([WmiClass]'Win32_SecurityDescriptorHelper').Win32SDToBinarySD($WmiSD).BinarySD
                } elseif ($TargetType -eq 'SDDL') {
                    return ([WmiClass]'Win32_SecurityDescriptorHelper').Win32SDToSDDL($WmiSD).SDDL
                }
            }
        }

        throw 'Unable to convert security descriptor to same type as input.'
    }
}

# Retrieve well-known security identifiers
Function Get-WellKnownSID {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseConsistentWhitespace', '')] # PSScriptAnalyzer bug
    [CmdletBinding()]
    [OutputType([Security.Principal.SecurityIdentifier])]
    Param(
        [Parameter(ParameterSetName = 'NTAuthority', Mandatory)]
        [ValidateSet('Anonymous', 'Authenticated Users', 'Batch', 'Claims Valid', 'Cloud Account Authentication', 'Compound Identity Present', 'Dialup', 'Digest Authentication', 'Enterprise Domain Controllers', 'IIS User', 'Interactive', 'Local Service', 'Local System', 'Microsoft Account Authentication', 'Network Service', 'Network', 'NTLM Authentication', 'Other Organization', 'Principal Self', 'Proxy', 'Remote Interactive Logon', 'Restricted', 'SChannel Authentication', 'Service', 'Terminal Server Users', 'This Organization Certificate', 'This Organization', 'User-mode Drivers', 'Write Restricted')]
        [String[]]$NTAuthority,

        [Parameter(ParameterSetName = 'Builtin', Mandatory)]
        [ValidateSet('Access Control Assistance Operators', 'Account Operators', 'Administrators', 'Backup Operators', 'Builtin', 'Certificate Service DCOM Access', 'Cryptographic Operators', 'Device Owners', 'Distributed COM Users', 'Event Log Readers', 'Guests', 'Hyper-V Administrators', 'IIS Users', 'Incoming Forest Trust Builders', 'Local account and member of Administrators group', 'Local account', 'Network Configuration Operators', 'Performance Log Users', 'Performance Monitor Users', 'Power Users', 'Pre-Windows 2000 Compatible Access', 'Print Operators', 'RDS Endpoint Servers', 'RDS Management Servers', 'RDS Remote Access Servers', 'Remote Desktop Users', 'Remote Management Users', 'Replicators', 'Server Operators', 'Storage Replica Administrators', 'System Managed Group', 'Terminal Server License Servers', 'Users', 'Windows Authorization Access Group')]
        [String[]]$Builtin,

        [Parameter(ParameterSetName = 'Domain', Mandatory)]
        [ValidateSet('Administrator', 'Allowed RODC Password Replication Group', 'Cert Publishers', 'Cloneable Domain Controllers', 'DefaultAccount', 'Denied RODC Password Replication Group', 'Domain Admins', 'Domain Computers', 'Domain Controllers', 'Domain Guests', 'Domain Users', 'Enterprise Admins', 'Enterprise Key Admins', 'Enterprise Read-only Domain Controllers', 'Group Policy Creator Owners', 'Guest', 'Key Admins', 'krbtgt', 'Protected Users', 'RAS and IAS Servers', 'Read-only Domain Controllers', 'Schema Admins', 'WDAGUtilityAccount')]
        [String[]]$Domain,

        [Parameter(ParameterSetName = 'Domain')]
        [ValidateNotNullOrEmpty()]
        [String]$DomainName,

        [Parameter(ParameterSetName = 'NullAuthority', Mandatory)]
        [ValidateSet('Nobody')]
        [String[]]$NullAuthority,

        [Parameter(ParameterSetName = 'WorldAuthority', Mandatory)]
        [ValidateSet('Everyone')]
        [String[]]$WorldAuthority,

        [Parameter(ParameterSetName = 'LocalAuthority', Mandatory)]
        [ValidateSet('Console Logon', 'Local')]
        [String[]]$LocalAuthority,

        [Parameter(ParameterSetName = 'CreatorAuthority', Mandatory)]
        [ValidateSet('Creator Group Server', 'Creator Group', 'Creator Owner Server', 'Creator Owner', 'Owner Rights')]
        [String[]]$CreatorAuthority,

        [Parameter(ParameterSetName = 'NTService', Mandatory)]
        [ValidateSet('All Services', 'NT Service')]
        [String[]]$NTService,

        [Parameter(ParameterSetName = 'NTVirtualMachine', Mandatory)]
        [ValidateSet('NT Virtual Machine', 'Virtual Machines')]
        [String[]]$NTVirtualMachine,

        [Parameter(ParameterSetName = 'NTTask', Mandatory)]
        [ValidateSet('NT Task')]
        [String[]]$NTTask,

        [Parameter(ParameterSetName = 'WindowManager', Mandatory)]
        [ValidateSet('Window Manager', 'Window Manager Group')]
        [String[]]$WindowManager,

        [Parameter(ParameterSetName = 'FontDriverHost', Mandatory)]
        [ValidateSet('Font Driver Host')]
        [String[]]$FontDriverHost,

        [Parameter(ParameterSetName = 'ApplicationPackageAuthority', Mandatory)]
        [ValidateSet('All Application Packages')]
        [String[]]$ApplicationPackageAuthority,

        [Parameter(ParameterSetName = 'MandatoryLabel', Mandatory)]
        [ValidateSet('High Mandatory Level', 'Low Mandatory Level', 'Medium Mandatory Level', 'Medium Plus Mandatory Level', 'Protected Process Mandatory Level', 'Secure Process Mandatory Level', 'System Mandatory Level', 'Untrusted Mandatory Level')]
        [String[]]$MandatoryLabel,

        [Parameter(ParameterSetName = 'IdentityAuthority', Mandatory)]
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
                Test-ModuleAvailable -Name 'ActiveDirectory'

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

                $DomainIdentifier = Get-ADObject -Server $Dc.HostName.Value -Identity $RootDse.defaultNamingContext -Properties 'objectSid'
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

    return [Security.Principal.SecurityIdentifier]$SID
}

#endregion

#region User accounts

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

#endregion

Complete-DotFilesSection
