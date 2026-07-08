#region Environment

# Confirm a command is available
Function Test-CommandAvailable {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name
    )

    foreach ($Command in $Name) {
        try {
            Write-Debug -Message "Checking command is available: ${Command}"
            $Result = Get-Command -Name $Command -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

        # If a command name has a wildcard an exception will not be thrown
        if ($null -eq $Result) {
            $ExcMsg = "Command matching wildcard not found: ${Command}"
            $ErrExc = [Management.Automation.CommandNotFoundException]::new($ExcMsg)
            $ErrExc.CommandName = $Command
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'CommandNotFoundException', $ErrCat, $Command)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Check environment matches expectations
Function Test-EnvironmentMatch {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]$Environment
    )

    foreach ($EnvName in $Environment.Keys) {
        Write-Debug -Message "Checking for environment variable: ${EnvName}"

        $EnvExpectedValue = $Environment[$EnvName]
        $EnvCurrentValue = [Environment]::GetEnvironmentVariable($EnvName)

        if (!($EnvExpectedValue -is [Boolean] -or $EnvExpectedValue -is [String])) {
            $ExcMsg = 'Value for key "{0}" is not a Boolean or String type.' -f $EnvName
            $ErrExc = [ArgumentException]::new($ExcMsg, 'Environment')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidType
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidType', $ErrCat, $EnvExpectedValue)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        # An empty string is an invalid value on Windows
        if ((Test-IsWindows) -and $EnvExpectedValue -is [String] -and $EnvExpectedValue -eq '') {
            $ExcMsg = 'Environment variable "{0}" cannot be set to an empty string on Windows.' -f $EnvName
            $ErrExc = [NotSupportedException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableInvalid', $ErrCat, $EnvExpectedValue)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        if ($EnvExpectedValue -is [Boolean]) {
            # Environment variable must not exist
            if ($EnvExpectedValue -eq $false) {
                if ($null -eq $EnvCurrentValue) { continue }

                $ExcMsg = "Environment variable exists: ${EnvName}"
                $ErrExc = [InvalidOperationException]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::ResourceExists
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableExists', $ErrCat, $EnvName)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            # Environment variable must exist (any value)
            if ($null -ne $EnvCurrentValue) { continue }

            $ExcMsg = "Environment variable not set: ${EnvName}"
            $ErrExc = [InvalidOperationException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableNotFound', $ErrCat, $EnvName)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        if ($null -eq $EnvCurrentValue) {
            $ExcMsg = "Environment variable not set: ${EnvName}"
            $ErrExc = [InvalidOperationException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableNotFound', $ErrCat, $EnvName)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        if ($EnvExpectedValue -cne $EnvCurrentValue) {
            $ExcMsg = 'Environment variable "{0}" set to "{1}" but expected "{2}".' -f $EnvName, $EnvCurrentValue, $EnvExpectedValue
            $ErrExc = [InvalidOperationException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableMismatch', $ErrCat, $EnvName)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Check if we're running on Linux
Function Test-IsLinux {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    return $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
}

# Check if we're running on macOS
Function Test-IsMacOS {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    return $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS
}

# Check if we're running on a Unix-like platform (Linux or macOS)
Function Test-IsUnix {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    return $PSVersionTable.PSVersion.Major -ge 6 -and ($IsLinux -or $IsMacOS)
}

# Check if we're running on Windows
Function Test-IsWindows {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    return $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows
}

# Confirm a PowerShell module is available
Function Test-ModuleAvailable {
    [CmdletBinding()]
    [OutputType([Void], [PSModuleInfo[]])]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name,

        [ValidateSet('Get', 'Import')]
        [String]$Operation = 'Get',

        [ValidateSet('Any', 'All')]
        [String]$Require = 'All',

        [Switch]$PassThru
    )

    $FoundModule = $false
    $MissingModule = $false
    $MissingModuleName = $null

    if ($PassThru) {
        $ModuleInfo = [Collections.Generic.List[PSModuleInfo]]::new()
    }

    foreach ($Module in $Name) {
        Write-Debug -Message "Checking module is available: ${Module}"

        if ($Operation -eq 'Get') {
            $ModuleAvailable = @(Get-Module -Name $Module -ListAvailable -Verbose:$false)
        } else {
            try {
                # Suppress verbose output on import
                $VerboseOriginal = $Global:VerbosePreference
                $Global:VerbosePreference = 'SilentlyContinue'

                # Ensure we always load into the global scope. When running
                # asynchronously the default is the transient module scope.
                $ModuleAvailable = Import-Module -Name $Module -Scope 'Global' -PassThru -ErrorAction 'Stop' -Verbose:$false
            } catch {
                $ModuleAvailable = $null

                $ErrRec = $PSItem
                switch -Regex ($ErrRec.FullyQualifiedErrorId) {
                    '^Modules_ModuleNotFound,' { $Error.RemoveAt(0) }
                    default { $PSCmdlet.ThrowTerminatingError($ErrRec) }
                }
            } finally {
                $Global:VerbosePreference = $VerboseOriginal
            }
        }

        if ($ModuleAvailable) {
            $FoundModule = $true

            if ($PassThru) {
                $ModuleInfo.Add(($ModuleAvailable | Sort-Object -Property 'Version' -Descending | Select-Object -First 1))
            }

            if ($Require -eq 'Any') { break }
        } else {
            $MissingModule = $true
            $MissingModuleName = $Module

            if ($Require -eq 'All') { break }
        }
    }

    $ThrowError = $false
    if ($Require -eq 'Any' -and !$FoundModule) {
        $ThrowError = $true
        $ErrObj = $Name -join ', '
        $ExcMsg = "Suitable module not available: ${ErrObj}"
    } elseif ($Require -eq 'All' -and $MissingModule) {
        $ThrowError = $true
        $ErrObj = $MissingModuleName
        $ExcMsg = "Required module not available: ${ErrObj}"
    }

    if ($ThrowError) {
        $ErrExc = [IO.FileNotFoundException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ResourceUnavailable
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'Modules_ModuleNotFound', $ErrCat, $ErrObj)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PassThru) {
        return $ModuleInfo.ToArray()
    }
}

#endregion

#region Filesystem

# Test if a path is fully qualified
#
# We can't simply use `[IO.Path]::IsPathFullyQualified()` in all cases as it's
# not available in .NET Framework (i.e. Windows PowerShell releases).
Function Test-IsPathFullyQualified {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path
    )

    # PowerShell 6 or later is guaranteed to have `IsPathFullyQualified()` as
    # it will be running under .NET (formerly .NET Core).
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return [IO.Path]::IsPathFullyQualified($Path)
    }

    # Windows PowerShell uses .NET Framework so we have to do this ourselves.
    # The below logic is taken from the .NET source code. It's well commented
    # so check the original method to understand these checks.

    if ($Path.Length -lt 2) {
        return $false
    }

    if ($Path[0] -eq [IO.Path]::DirectorySeparatorChar -or $Path[0] -eq [IO.Path]::AltDirectorySeparatorChar) {
        return $Path[1] -eq '?' -or $Path[1] -eq [IO.Path]::DirectorySeparatorChar -or $Path[1] -eq [IO.Path]::AltDirectorySeparatorChar
    }

    if ($Path.Length -lt 3) {
        return $false
    }

    return $Path[0] -match '[A-Za-z]' -and $Path[1] -eq ':' -and ($Path[2] -eq [IO.Path]::DirectorySeparatorChar -or $Path[2] -eq [IO.Path]::AltDirectorySeparatorChar)
}

#endregion

#region Profile

# Clean-up `dotfiles` profile loading data
Function Clear-DotFilesLoadData {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $Functions = @(
        'Clear-DotFilesLoadData'
        'Complete-DotFilesSection'
        'Get-DotFilesTiming'
        'Invoke-DotFilesAsyncTask'
        'Start-DotFilesSection'
        'Write-DotFilesMessage'
    )

    $Variables = @(
        # Settings
        'DotFilesFastLoad'
        'DotFilesLoadAsync'
        'DotFilesTimings'
        'DotFilesVerbose'

        # State
        'AsyncLoadQueue'
        'DotFilesIsAsync'
        'DotFilesProfileStopwatch'
        'DotFilesSection'
        'DotFilesSectionName'
        'DotFilesSectionStopwatch'
        'DotFilesSectionType'
        'FormatDataPaths'
        'PoshCompletionsPath'
        'PoshThemesPath'
    )

    if ($Global:DotFilesVerbose) {
        # Refer to the comment in `Microsoft.PowerShell_profile.ps1`
        $Global:VerbosePreference = 'SilentlyContinue'
    }

    foreach ($Name in $Functions) {
        Remove-Item -LiteralPath "Function:\${Name}" -ErrorAction 'Ignore'
    }

    foreach ($Name in $Variables) {
        Remove-Variable -Name $Name -Scope 'Global' -ErrorAction 'Ignore'
    }
}

# Complete a `dotfiles` section and conditionally output timings
Function Complete-DotFilesSection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if ($Global:DotFilesIsAsync) {
        Write-DotFilesMessage -Type 'Debug' -Message 'Completing async section processing ...'
    } else {
        Write-DotFilesMessage -Type 'Debug' -Message 'Completing section processing ...'
    }

    if ($Global:DotFilesTimings) {
        if ($Global:DotFilesSectionStopwatch -isnot [Diagnostics.Stopwatch]) {
            $ExcMsg = 'No stopwatch found for section timing.'
            $ErrExc = [InvalidOperationException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidOperation
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'DotFilesInvalidState', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $Global:DotFilesSectionStopwatch.Stop()
        Write-DotFilesMessage -Type 'Verbose' -Message (Get-DotFilesTiming -Stopwatch $Global:DotFilesSectionStopwatch)
    }

    Remove-Variable -Name 'DotFilesSectionName', 'DotFilesSectionType' -Scope 'Global' -ErrorAction 'Ignore'
}

# Retrieve the elapsed time for a `dotfiles` section
Function Get-DotFilesTiming {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory)]
        [Diagnostics.Stopwatch]$Stopwatch,

        [UInt16]$SlowThresholdMs = 100,
        [UInt16]$UltraSlowThresholdMs = 300
    )

    $Timing = "Elapsed time: $($Stopwatch.ElapsedMilliseconds) ms"

    if ($Stopwatch.ElapsedMilliseconds -ge $UltraSlowThresholdMs) {
        $Timing += ' [ULTRA SLOW]'
    } elseif ($Stopwatch.ElapsedMilliseconds -ge $SlowThresholdMs) {
        $Timing += ' [SLOW]'
    }

    return $Timing
}

# Dequeue a `dotfiles` task from the asynchronous loading queue
Function Invoke-DotFilesAsyncTask {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    # If the profile was (re)loaded with verbose mode enabled ensure that's
    # also the case for asynchronous processing.
    if ($Global:DotFilesVerbose) {
        $VerbosePreference = 'Continue'

        # To avoid misalignment if the prompt has already been output
        Write-Host
    }

    if ($Global:DotFilesTimings) {
        $Global:DotFilesSectionStopwatch.Restart()
    }

    if ($Global:AsyncLoadQueue.Count -ne 0) {
        try {
            $Global:DotFilesIsAsync = $true

            # `$null` assignment should be unnecessary but is a precaution
            # against accidental pipeline pollution from uncaptured output.
            $null = & $Global:AsyncLoadQueue.Dequeue()
        } catch {
            $ExcMsg = "Exception was thrown processing an async task: $($PSItem.Exception.Message)"
            $ErrExc = [Exception]::new($ExcMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'DotFilesAsyncTaskFailure', $ErrCat, $null)
            $PSCmdlet.WriteError($ErrRec)
        } finally {
            $Global:DotFilesIsAsync = $false
        }
    }

    $MoreAsyncTasks = $true
    if ($Global:AsyncLoadQueue.Count -eq 0) {
        $MoreAsyncTasks = $false
        Write-DotFilesMessage -Type 'Verbose' -SectionType 'Profile' -SectionName 'End' -Message 'Finished asynchronous processing.'
    }

    return $MoreAsyncTasks
}

# Start a `dotfiles` section with optional prerequisite checks
#
# Parameter validation via attributes is deliberately less strict for optional
# parameters than typical. Specifically, we permit:
# - `Platform`
#   Empty string.
# - `PwshMinVersion`
#   `$null` value.
# - `PwshHostName`, `Command`, `Environment`, `Module`
#   `$null` value or empty array.
#
# The reason is Windows PowerShell throws an exception when creating the
# closure for the asynchronous scriptblock if any function parameters fail
# validation, even if they weren't provided for the function invocation.
Function Start-DotFilesSection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param(
        [Parameter(Mandatory)]
        [String]$Type,

        [Parameter(Mandatory)]
        [String]$Name,

        [ValidateSet('', 'Unix', 'Windows')]
        [String]$Platform,

        [Version]$PwshMinVersion,
        [String[]]$PwshHostName,

        # `Test-CommandAvailable`
        [String[]]$Command,

        # `Test-EnvironmentMatch`
        [Hashtable]$Environment,

        # `Test-ModuleAvailable`
        [String[]]$Module,

        [ValidateSet('Get', 'Import')]
        [String]$ModuleOperation = 'Get',

        [ValidateSet('Any', 'All')]
        [String]$ModuleRequire = 'All',

        [Switch]$ForceTestModule,
        [Switch]$Async
    )

    $Global:DotFilesSectionType = $Type
    $Global:DotFilesSectionName = $Name

    if ($Global:DotFilesIsAsync) {
        Write-DotFilesMessage -Type 'Debug' -Message 'Starting async section processing ...'
    } else {
        Write-DotFilesMessage -Type 'Debug' -Message 'Starting section processing ...'
    }

    if (!$Global:DotFilesIsAsync) {
        # Run the platform, PowerShell version, and PowerShell host checks
        # up-front as they're both cheap and static for a given session.

        if ($Platform) {
            if ($Platform -eq 'Windows' -and !(Test-IsWindows)) {
                Write-DotFilesMessage -Type 'Verbose' -Message 'Skipping as platform is not Windows.'
                return $false
            }

            if ($Platform -eq 'Unix' -and !(Test-IsUnix)) {
                Write-DotFilesMessage -Type 'Verbose' -Message 'Skipping as platform is not Unix-like.'
                return $false
            }
        }

        if ($PwshMinVersion -and $PwshMinVersion -gt $PSVersionTable.PSVersion) {
            Write-DotFilesMessage -Type 'Verbose' -Message "Skipping as PowerShell version is below minimum: ${PwshMinVersion}"
            return $false
        }

        if ($PwshHostName -and $Host.Name -notin $PwshHostName) {
            Write-DotFilesMessage -Type 'Verbose' -Message "Skipping as PowerShell host is not supported: $($Host.Name)"
            return $false
        }

        if ($Async -and $Global:DotFilesLoadAsync) {
            $CallStack = Get-PSCallStack

            # Ensure any state that should persist in the session is set in the
            # global scope. Changes made in all other scopes will be discarded
            # on completion as they're loaded into the transient module scope.
            $AsyncLoadScript = {
                . $CallStack[1].ScriptName
            }.GetNewClosure()

            $Global:AsyncLoadQueue.Enqueue($AsyncLoadScript)

            # Return `$false` to halt further synchronous processing
            Write-DotFilesMessage -Type 'Verbose' -Message 'Initial prerequisite checks passed.'
            return $false
        }
    }

    if ($Command) {
        try {
            Test-CommandAvailable -Name $Command
        } catch {
            $ErrRec = $PSItem
            switch -Regex ($ErrRec.FullyQualifiedErrorId) {
                '^CommandNotFoundException,' {
                    Write-DotFilesMessage -Type 'Verbose' -Message "Skipping as command not available: $($ErrRec.Exception.CommandName)"
                    $Error.RemoveAt(0)
                    return $false
                }

                default { $PSCmdlet.ThrowTerminatingError($ErrRec) }
            }
        }
    }

    if ($Environment -and $Environment.Count -ne 0) {
        try {
            Test-EnvironmentMatch -Environment $Environment
        } catch {
            $ErrRec = $PSItem
            switch -Regex ($ErrRec.FullyQualifiedErrorId) {
                '^EnvironmentVariable(Exists|NotFound|Mismatch),' {
                    $ExcMsg = $ErrRec.Exception.Message
                    Write-DotFilesMessage -Type 'Verbose' -Message ('Skipping as {0}{1}' -f [Char]::ToLowerInvariant($ExcMsg[0]), $ExcMsg.Substring(1))
                    $Error.RemoveAt(0)
                    return $false
                }

                default { $PSCmdlet.ThrowTerminatingError($ErrRec) }
            }
        }
    }

    $ProcessModules = $ModuleOperation -eq 'Import' -or $ForceTestModule -or !$Global:DotFilesFastLoad
    if ($Module -and $ProcessModules) {
        try {
            Test-ModuleAvailable -Name $Module -Operation $ModuleOperation -Require $ModuleRequire
        } catch {
            $ErrRec = $PSItem
            switch -Regex ($ErrRec.FullyQualifiedErrorId) {
                '^Modules_ModuleNotFound,' {
                    $ExcMsg = $ErrRec.Exception.Message
                    Write-DotFilesMessage -Type 'Verbose' -Message ('Skipping as {0}{1}' -f [Char]::ToLowerInvariant($ExcMsg[0]), $ExcMsg.Substring(1))
                    $Error.RemoveAt(0)
                    return $false
                }

                default { $PSCmdlet.ThrowTerminatingError($ErrRec) }
            }
        }
    }

    Write-DotFilesMessage -Type 'Verbose' -Message 'All prerequisites met.'
    return $true
}

# Write a formatted `dotfiles` message
Function Write-DotFilesMessage {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('Debug', 'Verbose', 'Warning')]
        [String]$Type,

        [Parameter(Mandatory)]
        [String]$Message,

        [ValidateNotNullOrEmpty()]
        [String]$SectionType,

        [ValidateNotNullOrEmpty()]
        [String]$SectionName
    )

    if (!$SectionType) {
        if (!$Global:DotFilesSectionType) {
            $ExcMsg = 'SectionType parameter was not provided and no global value is defined.'
            $ErrExc = [InvalidOperationException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidOperation
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'DotFilesInvalidState', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $SectionType = $Global:DotFilesSectionType
    }

    if (!$SectionName) {
        if (!$Global:DotFilesSectionName) {
            $ExcMsg = 'SectionName parameter was not provided and no global value is defined.'
            $ErrExc = [InvalidOperationException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidOperation
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'DotFilesInvalidState', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $SectionName = $Global:DotFilesSectionName
    }

    if ($Global:DotFilesLoadAsync) {
        if ($Global:DotFilesIsAsync) {
            $LoadType = 'Async'
        } else {
            $LoadType = 'Sync'
        }

        $Msg = '[dotfiles | {0,-10} | {1,-25} | {2,-5}] {3}' -f $SectionType, $SectionName, $LoadType, $Message
    } else {
        $Msg = '[dotfiles | {0,-10} | {1,-25}] {2}' -f $SectionType, $SectionName, $Message
    }

    switch ($Type) {
        'Debug' { Write-Debug -Message $Msg }
        'Verbose' { Write-Verbose -Message $Msg }
        'Warning' { Write-Warning -Message $Msg }
    }
}

#endregion
