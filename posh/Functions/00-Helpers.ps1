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
            $null = Get-Command -Name $Command -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
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
            $ErrMsg = 'Value for key "{0}" is not a Boolean or String type.' -f $EnvName
            $ErrExc = [ArgumentException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidType
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidType', $ErrCat, $EnvExpectedValue)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        # An empty string is an invalid environment variable value on Windows
        if ((Test-IsWindows) -and $EnvExpectedValue -is [String] -and $EnvExpectedValue -eq '') {
            $ErrMsg = 'Environment variable "{0}" cannot be set to an empty string on Windows.' -f $EnvName
            $ErrExc = [NotSupportedException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableInvalid', $ErrCat, $EnvExpectedValue)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        if ($EnvExpectedValue -is [Boolean]) {
            # Environment variable must not exist
            if ($EnvExpectedValue -eq $false) {
                if ($null -eq $EnvCurrentValue) { continue }

                $ErrMsg = "Environment variable exists: ${EnvName}"
                $ErrExc = [InvalidOperationException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::ResourceExists
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableExists', $ErrCat, $EnvName)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            # Environment variable must exist (any value)
            if ($null -ne $EnvCurrentValue) { continue }

            $ErrMsg = "Environment variable not set: ${EnvName}"
            $ErrExc = [InvalidOperationException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableNotFound', $ErrCat, $EnvName)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        if ($null -eq $EnvCurrentValue) {
            $ErrMsg = "Environment variable not set: ${EnvName}"
            $ErrExc = [InvalidOperationException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableNotFound', $ErrCat, $EnvName)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        if ($EnvExpectedValue -cne $EnvCurrentValue) {
            $ErrMsg = 'Environment variable "{0}" set to "{1}" but expected "{2}".' -f $EnvName, $EnvCurrentValue, $EnvExpectedValue
            $ErrExc = [InvalidOperationException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'EnvironmentVariableMismatch', $ErrCat, $EnvName)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Naive check for running on a Unix-like system
Function Test-IsUnix {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    return !(Test-IsWindows)
}

# Naive check for running on a Windows system
Function Test-IsWindows {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    return $PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.Platform -eq 'Win32NT'
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

                # Ensure we always load into the global scope. This isn't the
                # default if running asynchronously (e.g. an event callback).
                Import-Module -Name $Module -Scope 'Global' -ErrorAction 'Ignore' -Verbose:$false
            } finally {
                $Global:VerbosePreference = $VerboseOriginal
            }

            $ModuleAvailable = @(Get-Module -Name $Module -Verbose:$false)
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
        $ErrMsg = "Suitable module not available: ${ErrObj}"
    } elseif ($Require -eq 'All' -and $MissingModule) {
        $ThrowError = $true
        $ErrObj = $MissingModuleName
        $ErrMsg = "Required module not available: ${ErrObj}"
    }

    if ($ThrowError) {
        $ErrExc = [IO.FileNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotFound', $ErrCat, $ErrObj)
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
# not available in .NET Framework (i.e. not available in Windows PowerShell).
Function Test-IsPathFullyQualified {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path
    )

    # PowerShell 6 or later is guaranteed to have `IsPathFullyQualified()` as
    # it won't be running under .NET Framework.
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return [IO.Path]::IsPathFullyQualified($Path)
    }

    # PowerShell 5 or earlier is .NET Framework so we have to do it ourselves.
    # The below logic is taken from the .NET Core source code. It's very well
    # commented so check the original method for understanding these checks.
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
        'DotFilesSectionStopwatch'
        'DotFilesVerboseOriginal'
        'FormatDataPaths'
        'PoshCompletionsPath'
    )

    if ($Global:DotFilesVerbose -or $Global:VerbosePreference -eq 'Continue') {
        $Global:VerbosePreference = $Global:DotFilesVerboseOriginal
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
            $ErrMsg = 'No stopwatch found for section timing.'
            $ErrExc = [InvalidOperationException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::MetadataError
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'DotFilesInvalidState', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $Global:DotFilesSectionStopwatch.Stop()
        $Timing = Get-DotFilesTiming -Stopwatch $Global:DotFilesSectionStopwatch
        Write-DotFilesMessage -Type 'Verbose' -Message $Timing
    }

    Remove-Variable -Name 'DotFilesSectionName', 'DotFilesSectionType' -Scope 'Global'
}

# Retrieve the elapsed time for a `dotfiles` section
Function Get-DotFilesTiming {
    [CmdletBinding()]
    [OutputType([Void], [String])]
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

# Start a `dotfiles` section with optional prerequisite checks
#
# Parameter validation via parameter validation attributes is deliberately less
# strict for optional parameters than typical. Specifically, we permit:
# - An empty string for `Platform`
# - `null` for `PwshMinVersion`
# - `null` or an empty array for `PwshHostName`, `Command`, `Environment`, and
#   `Module`
#
# The reason for doing this is Windows PowerShell 5.1 will throw an error when
# creating the closure for the asynchronous loading scriptblock if any function
# parameters fail validation, even if not present in the function invocation.
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

        # Test-CommandAvailable
        [String[]]$Command,

        # Test-EnvironmentMatch
        [Hashtable]$Environment,

        # Test-ModuleAvailable
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

            $AsyncLoadScript = {
                $Global:DotFilesIsAsync = $true

                if ($Global:DotFilesTimings) {
                    if (!$Global:DotFilesSectionStopwatch) {
                        $Global:DotFilesSectionStopwatch = [Diagnostics.Stopwatch]::new()
                    }

                    $Global:DotFilesSectionStopwatch.Restart()
                }

                if ($Global:DotFilesVerbose) { Write-Host }
                . $CallStack[1].ScriptName
            }.GetNewClosure()

            $Global:AsyncLoadQueue.Enqueue($AsyncLoadScript)

            # Return `false` to halt further synchronous processing
            Write-DotFilesMessage -Type 'Verbose' -Message 'All prerequisites met.'
            return $false
        }
    }

    if (!$Async -or !$Global:DotFilesLoadAsync -or $Global:DotFilesIsAsync) {
        if ($Command) {
            try {
                Test-CommandAvailable -Name $Command
            } catch {
                Write-DotFilesMessage -Type 'Verbose' -Message "Command(s) not available: $($PSItem.Exception.CommandName)"
                $Error.RemoveAt(0)
                return $false
            }
        }

        if ($Environment) {
            try {
                Test-EnvironmentMatch -Environment $Environment
            } catch {
                Write-DotFilesMessage -Type 'Verbose' -Message $PSItem.Exception.Message
                $Error.RemoveAt(0)
                return $false
            }
        }

        $ProcessModules = $ModuleOperation -eq 'Import' -or $ForceTestModule -or !$Global:DotFilesFastLoad
        if ($Module -and $ProcessModules) {
            try {
                Test-ModuleAvailable -Name $Module -Operation $ModuleOperation -Require $ModuleRequire
            } catch {
                Write-DotFilesMessage -Type 'Verbose' -Message $PSItem.Exception.Message
                $Error.RemoveAt(0)
                return $false
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
        $SectionType = $Global:DotFilesSectionType
    }

    if (!$SectionName) {
        $SectionName = $Global:DotFilesSectionName
    }

    if ($Global:DotFilesLoadAsync) {
        if ($Global:DotFilesIsAsync) { $LoadType = 'Async' } else { $LoadType = 'Sync' }
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
