$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Windows'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

#region Desktop

# Disable presentation mode
Function Disable-PresentationMode {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    & "${Env:SystemRoot}\System32\PresentationSettings.exe" /stop
}

# Enable presentation mode
Function Enable-PresentationMode {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    & "${Env:SystemRoot}\System32\PresentationSettings.exe" /start
}

#endregion

#region Environment variables

# Retrieve an environment variable
Function Get-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([String], [PSCustomObject[]])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [ValidateSet('Machine', 'User', 'Process')]
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

# Set an environment variable
Function Set-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Value,

        [ValidateSet('Machine', 'User', 'Process')]
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
            'Append' { $NewValue = "${CurrentValue}${Value}" }
            'Prepend' { $NewValue = "${Value}${CurrentValue}" }
        }

        [Environment]::SetEnvironmentVariable($Name, $NewValue, [EnvironmentVariableTarget]::$Scope)
    }
}

# Remove an environment variable
Function Remove-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [ValidateSet('Machine', 'User', 'Process')]
        [String]$Scope = 'User'
    )

    [Environment]::SetEnvironmentVariable($Name, $null, [EnvironmentVariableTarget]::$Scope)
}

#endregion

#region Event logs

# `dmesg` for Windows
Function dmesg {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([Void], [String[]], [Diagnostics.Eventing.Reader.EventLogRecord[]])]
    Param(
        [Parameter(ParameterSetName = 'MinSeverity', Mandatory)]
        [ValidateSet('Any', 'Critical', 'Error', 'Warning', 'Info', 'Verbose')]
        [String]$MinSeverityLevel,

        [ValidateSet('EventLogRecord', 'PlainText', 'PlainTextMinimal')]
        [String]$OutputFormat = 'EventLogRecord',

        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,

        [Switch]$Force
    )

    $Filter = @(
        '*-FilterManager'
        '*-HAL'
        '*-Hypervisor'
        '*-IsolatedUserMode'
        '*-Kernel-*'
        '*-Ntfs'
        '*-TPM-*'
        '*-Wininit'
        '*-Winlogon'
        'TPM'
        'Win32k'
    )

    Find-WinEvent -Filter $Filter @PSBoundParameters
}

# Find events by filtering against logs and providers
Function Find-WinEvent {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([Void], [String[]], [Diagnostics.Eventing.Reader.EventLogRecord[]])]
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

    $CommonParams = @{}

    if ($ComputerName) {
        $CommonParams['ComputerName'] = $ComputerName
    }

    # Default to boot time as start time
    if (!$StartTime) {
        try {
            $StartTime = (Get-CimInstance @CommonParams -ClassName 'Win32_OperatingSystem' -ErrorAction 'Stop').LastBootUpTime
        } catch {
            $ErrMsg = "Failed to retrieve system boot time: $($PSItem.Exception.Message)"
            $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'WmiApiFailed', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }

    # EventLevel Enum
    # https://learn.microsoft.com/en-au/dotnet/api/system.diagnostics.tracing.eventlevel
    $EventLevelNameToInt = @{
        Any      = 0
        Critical = 1
        Error    = 2
        Warning  = 3
        Info     = 4
        Verbose  = 5
    }

    # Configure event severity filtering
    $EventLevels = $null
    if ($PSCmdlet.ParameterSetName -eq 'SeverityLevel' -and $SeverityLevels -notcontains 'Any') {
        $EventLevels = [Collections.Generic.List[Int]]::new()
        foreach ($Severity in $SeverityLevels) {
            $EventLevels.Add($EventLevelNameToInt[$Severity])
        }
    } elseif ($PSCmdlet.ParameterSetName -eq 'MinSeverity' -and $MinSeverityLevel -ne 'Any') {
        $EventLevels = 0..$EventLevelNameToInt[$MinSeverityLevel]
    }

    # Retrieve matching event logs
    $EventLogs = [Collections.Generic.List[Diagnostics.Eventing.Reader.EventLogConfiguration]]::new()
    Get-WinEvent @CommonParams -ListLog $Filter -Force:$Force -ErrorAction 'Ignore' | Where-Object {
        # Explicitly excluded logs
        $PSItem.LogName -notin $ExcludedLogs -and
        # No records (must test both!)
        $null -ne $PSItem.RecordCount -and
        $PSItem.RecordCount -ne 0 -and
        # Written to since start time
        $PSItem.LastWriteTime -ge $StartTime
    } | ForEach-Object { $EventLogs.Add($PSItem) }

    # Retrieve matching event providers
    #
    # For each event provider record which event logs it outputs to. We'll
    # later retrieve events from these logs filtered by the event provider.
    # Exclude any logs which match the filter, as we'll retrieve all events
    # from these logs without any provider filter.
    $ProviderLogs = @{}
    $SkippedLogs = [Collections.Generic.List[String]]::new()
    foreach ($Provider in (Get-WinEvent @CommonParams -ListProvider $Filter -ErrorAction 'Ignore')) {
        $LogLinks = $Provider.LogLinks | Where-Object LogName -NotIn $ExcludedLogs

        foreach ($LogLink in $LogLinks) {
            $LogName = $LogLink.LogName

            # Check if event log matches a filter
            $LogFiltered = $false
            foreach ($Entry in $Filter) {
                if ($LogName -like $Entry) {
                    $LogFiltered = $true
                    break
                }
            }

            # Event log is already included by filter
            if ($LogFiltered) { continue }

            # Event log previously enumerated and inaccessible or irrelevant
            if ($SkippedLogs -contains $LogName) { continue }

            # Is this the first time we've seen this event log?
            if (!$ProviderLogs.ContainsKey($LogName)) {
                # Try to retrieve the event log
                try {
                    $EventLog = Get-WinEvent @CommonParams -ListLog $LogName -Force:$Force -ErrorAction 'Stop'
                } catch {
                    $PSCmdlet.WriteError($PSItem)
                    $SkippedLogs.Add($LogName)
                    continue
                }

                # No records or not written to since start time
                if ($null -eq $EventLog.RecordCount -or $EventLog.RecordCount -eq 0 -or $EventLog.LastWriteTime -lt $StartTime) {
                    $SkippedLogs.Add($LogName)
                    continue
                }

                $EventLogs.Add($EventLog)
                $ProviderLogs[$LogName] = [Collections.Generic.List[String]]::new()
            }

            $ProviderLogs[$LogName].Add($Provider.Name)
        }
    }

    if ($EventLogs.Count -eq 0) {
        $ErrMsg = 'No event logs or providers matched the filter.'
        $ErrExc = [Management.Automation.ItemNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'FilterReturnedNoMatches', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $WriteProgressParams = @{
        Activity = 'Retrieving Windows event logs'
    }

    # Retrieve all the events matching the filter
    $WinEvents = [Collections.Generic.List[Diagnostics.Eventing.Reader.EventLogRecord]]::new()
    for ($i = 0; $i -lt $EventLogs.Count; $i++) {
        $EventLog = $EventLogs[$i]
        $LogName = $EventLog.LogName

        Write-Progress @WriteProgressParams -Status $LogName -PercentComplete ($i / $EventLogs.Count * 100)

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
            Get-WinEvent @CommonParams @EventParams -ErrorAction 'Stop' |
                ForEach-Object { $WinEvents.Add($PSItem) }
        } catch {
            $Exc = $PSItem
            switch -Regex ($PSItem.FullyQualifiedErrorId) {
                '^NoMatchingEventsFound,' { continue }
                default {
                    Write-Warning -Message $Exc.Exception.Message
                    continue
                }
            }
        }
    }

    $SortedEvents = $WinEvents | Sort-Object -Property 'TimeCreated'
    Write-Progress @WriteProgressParams -Completed

    if ($OutputFormat -eq 'EventLogRecord') {
        return $SortedEvents
    }

    # User requested event log records be emitted as plain text

    # EventLevel Enum
    # https://learn.microsoft.com/en-au/dotnet/api/system.diagnostics.tracing.eventlevel
    $EventLevelIntToName = @(
        'Any'
        'Critical'
        'Error'
        'Warning'
        'Info'
        'Verbose'
    )

    # String formatting configuration
    $DateFormat = 'yyyy/MM/dd hh:mm:ss tt'
    $PrefixWhitespace = ' ' * ('[{0}] {1,-8} -> ' -f (Get-Date).ToString($DateFormat), $EventLevelIntToName[0]).Length
    $MultilinePrefix = "$([Environment]::NewLine)${PrefixWhitespace}"

    # Using the `TrimEntries` option would be convenient here but it's only
    # available from .NET 5 so can't be used in Windows PowerShell.
    $StringSplitOptions = [StringSplitOptions]::RemoveEmptyEntries

    $WinEvents = [Collections.Generic.List[String]]::new()
    foreach ($WinEvent in $SortedEvents) {
        $Time = $WinEvent.TimeCreated.ToString($DateFormat)
        $Provider = $WinEvent.ProviderName
        $EvtMsg = $WinEvent.Message

        if ($WinEvent.Level -lt $EventLevelIntToName.Count) {
            $Level = $EventLevelIntToName[$WinEvent.Level].ToUpper()
        } else {
            # Custom providers may define their own levels
            $Level = 'UNKNOWN'
        }

        # Left-to-right mark
        $ReplaceChars = [Char[]]@(0x200e)
        foreach ($Char in $ReplaceChars) {
            $EvtMsg = $EvtMsg.Replace([String]$Char, '')
        }

        if ($WinEvent.Message) {
            $EvtMsg = $EvtMsg.Split("`r`n", $StringSplitOptions).Split("`n", $StringSplitOptions).Trim() | Where-Object { ![String]::IsNullOrEmpty($PSItem) }
        } else {
            $EvtMsg = ''
        }

        if ($OutputFormat -eq 'PlainText') {
            $Text = '[{0}] {1,-8} -> {2}{3}{4}' -f $Time, $Level, $Provider, $MultilinePrefix, ($EvtMsg -join $MultilinePrefix)
        } else {
            $Text = '[{0}] {1,-8} -> {2}' -f $Time, $Level, ($EvtMsg -join $MultilinePrefix)
        }

        $WinEvents.Add($Text)
    }

    return $WinEvents.ToArray()
}

# Watch an event log (similar to Unix `tail`)
# Slightly improved from: https://stackoverflow.com/a/15262376/8787985
Function Watch-EventLog {
    [CmdletBinding()]
    [OutputType([Void], [Diagnostics.Eventing.Reader.EventLogRecord[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$LogName
    )

    $PreviousIndex = (Get-WinEvent -LogName $LogName -MaxEvents 1).RecordId

    do {
        Start-Sleep -Seconds 1
        $NewIndex = (Get-WinEvent -LogName $LogName -MaxEvents 1).RecordId

        if ($NewIndex -ne $PreviousIndex) {
            Get-WinEvent -LogName $LogName -MaxEvents ($NewIndex - $PreviousIndex) | Sort-Object -Property 'RecordId'
            $PreviousIndex = $NewIndex
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

        [ValidateRange(1, [UInt16]::MaxValue)]
        [UInt16]$MinimumHardLinks = 2,

        [Switch]$Recurse,
        [Switch]$Force
    )

    $Files = Get-ChildItem -LiteralPath $Path -File -Recurse:$Recurse -Force:$Force |
        Where-Object { $PSItem.LinkType -eq 'HardLink' -and $PSItem.Target.Count -ge ($MinimumHardLinks - 1) } |
        Add-Member -MemberType 'ScriptProperty' -Name 'LinkCount' -Value { $this.Target.Count + 1 } -Force -PassThru

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

    $Dirs = Get-ChildItem -LiteralPath $Path -Directory -Recurse:$Recurse -Force:$Force

    $AclMatches = [Collections.Generic.List[IO.DirectoryInfo]]::new()
    foreach ($Dir in $Dirs) {
        $Acl = Get-Acl -LiteralPath $Dir.FullName

        $AclNonInherited = $Acl.Access | Where-Object IsInherited -EQ $false
        if (!$AclNonInherited) { continue }

        if ($User -and $AclNonInherited.IdentityReference -notcontains $User) { continue }

        $AclMatches.Add($Dir)
    }

    return $AclMatches.ToArray()
}

# Helper function to call `cmd` built-in command `mklink`
Function mklink {
    [OutputType([String])]
    Param()

    & $Env:ComSpec /c mklink $args
}

#endregion

#region Networking

# Open the hosts file for editing
Function Edit-Hosts {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $Params = @{
        FilePath     = 'notepad.exe'
        ArgumentList = "${Env:SystemRoot}\System32\drivers\etc\hosts"
    }

    if (!(Test-IsAdministrator)) {
        $Params.Add('Verb', 'RunAs')
    }

    Start-Process @Params
}

# Restore connections to mapped network drives
Function Restore-MappedNetworkDrives {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $MappedDrives = Get-SmbMapping | Where-Object Status -EQ 'Unavailable'
    foreach ($MappedDrive in $MappedDrives) {
        Write-Verbose -Message "Restoring mapped network drive: $($MappedDrive.LocalPath)"
        try {
            $null = New-SmbMapping -LocalPath $MappedDrive.LocalPath -RemotePath $MappedDrive.RemotePath -Persistent $true -ErrorAction 'Stop'
        } catch {
            $ErrMsg = "Failed to restore mapped network drive: $($MappedDrive.LocalPath)"
            $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RestoreMappedNetworkDriveFailed', $ErrCat, $MappedDrive)
            $PSCmdlet.WriteError($ErrRec)
        }
    }
}

#endregion

#region Registry

# Search the registry
Function Search-Registry {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType(ParameterSetName = 'Default', [Void], [PSCustomObject[]])]
    [OutputType(ParameterSetName = 'Recursion', [Void])]
    Param(
        [Parameter(ParameterSetName = 'Default', Mandatory)]
        [ValidateSet('HKCC', 'HKCR', 'HKCU', 'HKLM', 'HKPD', 'HKU')]
        [String]$Hive,

        [Parameter(ParameterSetName = 'Default')]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$SimpleMatch,

        [ValidateSet('Keys', 'Values', 'Data')]
        [String[]]$Types = @('Keys', 'Values', 'Data'),

        [Parameter(ParameterSetName = 'Default')]
        [Switch]$NoRecurse,

        [Parameter(ParameterSetName = 'Recursion', Mandatory)]
        [Microsoft.Win32.RegistryKey]$ParentKey,

        [Parameter(ParameterSetName = 'Recursion', Mandatory)]
        [String]$SubKeyName,

        [Parameter(ParameterSetName = 'Recursion', Mandatory)]
        [AllowEmptyCollection()]
        [Collections.Generic.List[PSCustomObject]]$Results
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Default' {
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
            $SubKeys = @($Path.Split($DirSepChar))
            $OpenSubKeyFailed = $false

            # Traverse the path, opening each intermediate key
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
                    $RegPath = "$($SubKeys[-1])${DirSepChar}$($SubKeys[$RegKeys.Count - 1])"
                    $ErrMsg = "Failed to open registry key: ${RegPath}"
                    $ErrExc = [Management.Automation.ItemNotFoundException]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegistryKeyNotFound', $ErrCat, $RegPath)
                    $PSCmdlet.WriteError($ErrRec)
                    break
                }

                $RegKeys.Add($RegKey)
            }

            # We hit a failure, close all the opened keys
            if ($OpenSubKeyFailed) {
                for ($i = $RegKeys.Count - 1; $i -ne 0; $i--) {
                    $RegKeys[$i].Close()
                }

                return
            }

            $RegistryKey = $RegKeys[-1]
            $Results = [Collections.Generic.List[PSCustomObject]]::new()
        }

        'Recursion' {
            try {
                $RegistryKey = $ParentKey.OpenSubKey($SubKeyName)
                if (!$RegistryKey) {
                    $OpenSubKeyFailed = $true
                }
            } catch {
                $OpenSubKeyFailed = $true
            }

            if ($OpenSubKeyFailed) {
                $RegPath = "$($ParentKey.Name)$([IO.Path]::DirectorySeparatorChar)${SubKeyName}"
                Write-Verbose -Message "Failed to open registry key: ${RegPath}"
                return
            }

            $WriteProgressParams = @{
                Activity = "Searching registry for simple match: ${SimpleMatch}"
                Status   = $RegistryKey.Name
            }

            Write-Progress @WriteProgressParams
        }
    }

    $Recurse = $false
    if ($PSCmdlet.ParameterSetName -eq 'Recursion' -or !$NoRecurse) {
        $Recurse = $true

        $SearchParams = @{
            SimpleMatch = $SimpleMatch
            Types       = $Types
            ParentKey   = $RegistryKey
            SubKeyName  = ''
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

    $RdcDir = Join-Path -Path $DotFiles -ChildPath 'mstsc'
    $RdcTemplateFile = Join-Path -Path $RdcDir -ChildPath 'Template.ini'
    $RdcDefaultFile = Join-Path -Path $RdcDir -ChildPath 'Default.rdp'

    try {
        $RdcDefaultSettings = Get-Content -LiteralPath $RdcTemplateFile -ErrorAction 'Stop' |
            # Exclude comments and blank lines
            Where-Object { $PSItem -match '^[a-z]' } |
            # RDC always lowercases setting names
            ForEach-Object { $PSItem.ToLower() }
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    # UTF-16LE file encoding
    $Encoder = [Text.UnicodeEncoding]::new($false, $true)

    # We do this slightly convoluted dance to handle the case where the file
    # already exists and has the "Hidden" and/or "System" attributes.
    try {
        $FileStream = $StreamWriter = $null

        $FileStream = [IO.File]::Open($RdcDefaultFile, [IO.FileMode]::OpenOrCreate)
        $StreamWriter = [IO.StreamWriter]::new($FileStream, $Encoder, 1024, $true)

        foreach ($Line in $RdcDefaultSettings) {
            $StreamWriter.WriteLine($Line)
        }

        $StreamWriter.Flush()

        # Truncate any trailing data if the file already existed
        $FileStream.SetLength($FileStream.Position)
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    } finally {
        if ($StreamWriter) { $StreamWriter.Close() }
        if ($FileStream) { $FileStream.Dispose() }
    }

    # Match what RDC itself sets
    [IO.File]::SetAttributes($RdcDefaultFile, [IO.FileAttributes]'Archive,Hidden,System')
}

#endregion

#region Security

# Convert security descriptors between different formats
Function Convert-SecurityDescriptor {
    [CmdletBinding()]
    [OutputType(ParameterSetName = 'Binary', [String], [Management.ManagementBaseObject])]
    [OutputType(ParameterSetName = 'SDDL', [Byte[]], [Management.ManagementBaseObject])]
    [OutputType(ParameterSetName = 'WMI', [Byte[]], [String])]
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
                    $ErrMsg = "Expected Win32_SecurityDescriptor instance but received: $($WmiSD.__CLASS)"
                    $ErrExc = [ArgumentException]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $WmiSD)
                    $PSCmdlet.WriteError($ErrRec)
                    return
                }

                if ($TargetType -eq 'Binary') {
                    return ([WmiClass]'Win32_SecurityDescriptorHelper').Win32SDToBinarySD($WmiSD).BinarySD
                } elseif ($TargetType -eq 'SDDL') {
                    return ([WmiClass]'Win32_SecurityDescriptorHelper').Win32SDToSDDL($WmiSD).SDDL
                }
            }
        }

        $ErrMsg = 'Unable to convert security descriptor to same type as input.'
        $ErrExc = [ArgumentException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidType
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidType', $ErrCat, $null)
        $PSCmdlet.WriteError($ErrRec)
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
        [String]$NTAuthority,

        [Parameter(ParameterSetName = 'Builtin', Mandatory)]
        [ValidateSet('Access Control Assistance Operators', 'Account Operators', 'Administrators', 'Backup Operators', 'Builtin', 'Certificate Service DCOM Access', 'Cryptographic Operators', 'Device Owners', 'Distributed COM Users', 'Event Log Readers', 'Guests', 'Hyper-V Administrators', 'IIS Users', 'Incoming Forest Trust Builders', 'Local account and member of Administrators group', 'Local account', 'Network Configuration Operators', 'Performance Log Users', 'Performance Monitor Users', 'Power Users', 'Pre-Windows 2000 Compatible Access', 'Print Operators', 'RDS Endpoint Servers', 'RDS Management Servers', 'RDS Remote Access Servers', 'Remote Desktop Users', 'Remote Management Users', 'Replicators', 'Server Operators', 'Storage Replica Administrators', 'System Managed Group', 'Terminal Server License Servers', 'Users', 'Windows Authorization Access Group')]
        [String]$Builtin,

        [Parameter(ParameterSetName = 'Domain', Mandatory)]
        [ValidateSet('Administrator', 'Allowed RODC Password Replication Group', 'Cert Publishers', 'Cloneable Domain Controllers', 'DefaultAccount', 'Denied RODC Password Replication Group', 'Domain Admins', 'Domain Computers', 'Domain Controllers', 'Domain Guests', 'Domain Users', 'Enterprise Admins', 'Enterprise Key Admins', 'Enterprise Read-only Domain Controllers', 'Group Policy Creator Owners', 'Guest', 'Key Admins', 'krbtgt', 'Protected Users', 'RAS and IAS Servers', 'Read-only Domain Controllers', 'Schema Admins', 'WDAGUtilityAccount')]
        [String]$Domain,

        [Parameter(ParameterSetName = 'Domain')]
        [ValidateNotNullOrEmpty()]
        [String]$DomainName,

        [Parameter(ParameterSetName = 'NullAuthority', Mandatory)]
        [ValidateSet('Nobody')]
        [String]$NullAuthority,

        [Parameter(ParameterSetName = 'WorldAuthority', Mandatory)]
        [ValidateSet('Everyone')]
        [String]$WorldAuthority,

        [Parameter(ParameterSetName = 'LocalAuthority', Mandatory)]
        [ValidateSet('Console Logon', 'Local')]
        [String]$LocalAuthority,

        [Parameter(ParameterSetName = 'CreatorAuthority', Mandatory)]
        [ValidateSet('Creator Group Server', 'Creator Group', 'Creator Owner Server', 'Creator Owner', 'Owner Rights')]
        [String]$CreatorAuthority,

        [Parameter(ParameterSetName = 'NTService', Mandatory)]
        [ValidateSet('All Services', 'NT Service')]
        [String]$NTService,

        [Parameter(ParameterSetName = 'NTVirtualMachine', Mandatory)]
        [ValidateSet('NT Virtual Machine', 'Virtual Machines')]
        [String]$NTVirtualMachine,

        [Parameter(ParameterSetName = 'NTTask', Mandatory)]
        [ValidateSet('NT Task')]
        [String]$NTTask,

        [Parameter(ParameterSetName = 'WindowManager', Mandatory)]
        [ValidateSet('Window Manager', 'Window Manager Group')]
        [String]$WindowManager,

        [Parameter(ParameterSetName = 'FontDriverHost', Mandatory)]
        [ValidateSet('Font Driver Host')]
        [String]$FontDriverHost,

        [Parameter(ParameterSetName = 'ApplicationPackageAuthority', Mandatory)]
        [ValidateSet('All Application Packages')]
        [String]$ApplicationPackageAuthority,

        [Parameter(ParameterSetName = 'MandatoryLabel', Mandatory)]
        [ValidateSet('High Mandatory Level', 'Low Mandatory Level', 'Medium Mandatory Level', 'Medium Plus Mandatory Level', 'Protected Process Mandatory Level', 'Secure Process Mandatory Level', 'System Mandatory Level', 'Untrusted Mandatory Level')]
        [String]$MandatoryLabel,

        [Parameter(ParameterSetName = 'IdentityAuthority', Mandatory)]
        [ValidateSet('Authentication authority asserted identity', 'Fresh public key identity', 'Key property attestation', 'Key property multi-factor authentication', 'Key trust identity', 'Service asserted identity')]
        [String]$IdentityAuthority
    )

    switch ($PSCmdlet.ParameterSetName) {
        'NTAuthority' {
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

        'Builtin' {
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

        'Domain' {
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
                    $Dc = Get-ADDomainController -DomainName $DomainName -Discover -NextClosestSite -ErrorAction 'Stop'
                    $RootDse = Get-ADRootDSE -Server $Dc.HostName.Value -ErrorAction 'Stop'
                    $DomainIdentifier = Get-ADObject -Server $Dc.HostName.Value -Identity $RootDse.defaultNamingContext -Properties 'objectSid' -ErrorAction 'Stop'
                } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

                $SID = "$($DomainIdentifier.objectSid.Value)-${RID}"
            } else {
                $LocalUsers = Get-LocalUser
                $SID = "$($LocalUsers[0].SID.AccountDomainSid.Value)-${RID}"
            }
        }

        'NullAuthority' {
            switch ($NullAuthority) {
                'Nobody'                                            { $SID = 'S-1-0-0' }
            }
        }

        'WorldAuthority' {
            switch ($WorldAuthority) {
                'Everyone'                                          { $SID = 'S-1-1-0' }
            }
        }

        'LocalAuthority' {
            switch ($LocalAuthority) {
                'Local'                                             { $SID = 'S-1-2-0' }
                'Console Logon'                                     { $SID = 'S-1-2-1' }
            }
        }

        'CreatorAuthority' {
            switch ($CreatorAuthority) {
                'Creator Owner'                                     { $SID = 'S-1-3-0' }
                'Creator Group'                                     { $SID = 'S-1-3-1' }
                'Creator Owner Server'                              { $SID = 'S-1-3-2' }
                'Creator Group Server'                              { $SID = 'S-1-3-3' }
                'Owner Rights'                                      { $SID = 'S-1-3-4' }
            }
        }

        'NTService' {
            switch ($NTService) {
                'NT Service'                                        { $SID = 'S-1-5-80' }
                'All Services'                                      { $SID = 'S-1-5-80-0' }
            }
        }

        'NTVirtualMachine' {
            switch ($NTVirtualMachine) {
                'NT Virtual Machine'                                { $SID = 'S-1-5-83' }
                'Virtual Machines'                                  { $SID = 'S-1-5-83-0' }
            }
        }

        'NTTask' {
            switch ($NTTask) {
                'NT Task'                                           { $SID = 'S-1-5-87' }
            }
        }

        'WindowManager' {
            switch ($WindowManager) {
                'Window Manager'                                    { $SID = 'S-1-5-90' }
                'Window Manager Group'                              { $SID = 'S-1-5-90-0' }
            }
        }

        'FontDriverHost' {
            switch ($FontDriverHost) {
                'Font Driver Host'                                  { $SID = 'S-1-5-96' }
            }
        }

        'ApplicationPackageAuthority' {
            switch ($ApplicationPackageAuthority) {
                'All Application Packages'                          { $SID = 'S-1-15-2-1' }
            }
        }

        'MandatoryLabel' {
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

        'IdentityAuthority' {
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

# Test if the user has administrator privileges
Function Test-IsAdministrator {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    $User = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $User.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#endregion

Complete-DotFilesSection
