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

        if ($EnvExpectedValue -ne $EnvCurrentValue) {
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

    if ($PassThru) {
        $ModuleInfo = [Collections.Generic.List[PSModuleInfo]]::new()
    }

    $FoundModule = $false
    $MissingModule = $false
    foreach ($Module in $Name) {
        Write-Debug -Message "Checking module is available: ${Module}"

        if ($Operation -eq 'Get') {
            $ModuleAvailable = @(Get-Module -Name $Module -ListAvailable -Verbose:$false)
        } else {
            try {
                # Suppress verbose output on import
                $VerboseOriginal = $VerbosePreference
                $VerbosePreference = 'SilentlyContinue'
                Import-Module -Name $Module -ErrorAction 'Ignore' -Verbose:$false
            } finally {
                $VerbosePreference = $VerboseOriginal
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

# Complete a `dotfiles` section and conditionally output timings
Function Complete-DotFilesSection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    Write-Debug -Message (Get-DotFilesMessage -Message 'Completing section processing ...')

    if ($DotFilesShowTimings) {
        if ($Global:DotFilesSectionStart -isnot [DateTime]) {
            $ErrMsg = 'No start time found for section timing.'
            $ErrExc = [InvalidOperationException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::MetadataError
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'DotFilesInvalidState', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $Timing = Get-DotFilesTiming -StartTime $Global:DotFilesSectionStart
        Write-Verbose -Message (Get-DotFilesMessage -Message $Timing)
    }

    Remove-Variable -Name 'DotFilesSection*' -Scope 'Global'
}

# Retrieve a formatted `dotfiles` message
Function Get-DotFilesMessage {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([String])]
    Param(
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

    return '[dotfiles | {0,-10} | {1,-25}] {2}' -f $SectionType, $SectionName, $Message
}

# Retrieve the elapsed time for a `dotfiles` section
Function Get-DotFilesTiming {
    [CmdletBinding()]
    [OutputType([Void], [String])]
    Param(
        [Parameter(Mandatory)]
        [DateTime]$StartTime,

        [UInt16]$SlowThresholdMs = 100,
        [UInt16]$UltraSlowThresholdMs = 300
    )

    if (!$DotFilesShowTimings) { return }

    $ElapsedTime = (Get-Date) - $StartTime
    $Timing = "Elapsed time: $([Int]($ElapsedTime.TotalMilliseconds)) ms"

    if ($ElapsedTime.TotalMilliseconds -ge $UltraSlowThresholdMs) {
        $Timing += ' [ULTRA SLOW]'
    } elseif ($ElapsedTime.TotalMilliseconds -ge $SlowThresholdMs) {
        $Timing += ' [SLOW]'
    }

    return $Timing
}

# Remove `dotfiles` helper functions
Function Remove-DotFilesHelpers {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $Helpers = @(
        'Complete-DotFilesSection'
        'Get-DotFilesMessage'
        'Get-DotFilesTiming'
        'Remove-DotFilesHelpers'
        'Start-DotFilesSection'
    )

    foreach ($Helper in $Helpers) {
        try {
            Remove-Item -LiteralPath "Function:\${Helper}" -ErrorAction 'Stop'
        } catch { $PSCmdlet.WriteError($PSItem) }
    }
}

# Start a `dotfiles` section with optional prerequisite checks
Function Start-DotFilesSection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void], [Boolean])]
    Param(
        [Parameter(Mandatory)]
        [String]$Type,

        [Parameter(Mandatory)]
        [String]$Name,

        [ValidateSet('Unix', 'Windows')]
        [String]$Platform,

        [ValidateNotNull()]
        [Version]$PwshMinVersion,

        [ValidateNotNullOrEmpty()]
        [String[]]$PwshHostName,

        # Test-CommandAvailable
        [ValidateNotNullOrEmpty()]
        [String[]]$Command,

        # Test-EnvironmentMatch
        [ValidateNotNullOrEmpty()]
        [Hashtable]$Environment,

        # Test-ModuleAvailable
        [ValidateNotNullOrEmpty()]
        [String[]]$Module,

        [ValidateSet('Get', 'Import')]
        [String]$ModuleOperation = 'Get',

        [ValidateSet('Any', 'All')]
        [String]$ModuleRequire = 'All',

        [Switch]$ForceTestModule
    )

    $Global:DotFilesSectionType = $Type
    $Global:DotFilesSectionName = $Name

    if ($DotFilesShowTimings) {
        $Global:DotFilesSectionStart = Get-Date
    }

    Write-Debug -Message (Get-DotFilesMessage -Message 'Starting section processing ...')

    if (!($Platform -or $PwshMinVersion -or $PwshHostName -or $Command -or $Environment -or $Module)) {
        return $null
    }

    if ($Platform) {
        if ($Platform -eq 'Windows' -and !(Test-IsWindows)) {
            Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping as platform is not Windows.')
            return $false
        }

        if ($Platform -eq 'Unix' -and !(Test-IsUnix)) {
            Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping as platform is not Unix-like.')
            return $false
        }
    }

    if ($PwshMinVersion -and $PwshMinVersion -gt $PSVersionTable.PSVersion) {
        Write-Verbose -Message (Get-DotFilesMessage -Message "Skipping as PowerShell version is below minimum: ${PwshMinVersion}")
        return $false
    }

    if ($PwshHostName -and $Host.Name -notin $PwshHostName) {
        Write-Verbose -Message (Get-DotFilesMessage -Message "Skipping as PowerShell host is not supported: $($Host.Name)")
        return $false
    }

    if ($Command) {
        try {
            Test-CommandAvailable -Name $Command
        } catch {
            Write-Verbose -Message (Get-DotFilesMessage -Message $PSItem.Exception.Message)
            $Error.RemoveAt(0)
            return $false
        }
    }

    if ($Environment) {
        try {
            Test-EnvironmentMatch -Environment $Environment
        } catch {
            Write-Verbose -Message (Get-DotFilesMessage -Message $PSItem.Exception.Message)
            $Error.RemoveAt(0)
            return $false
        }
    }

    $ProcessModules = $ModuleOperation -eq 'Import' -or $ForceTestModule -or !$Global:DotFilesFastLoad
    if ($Module -and $ProcessModules) {
        try {
            Test-ModuleAvailable -Name $Module -Operation $ModuleOperation -Require $ModuleRequire
        } catch {
            Write-Verbose -Message (Get-DotFilesMessage -Message $PSItem.Exception.Message)
            $Error.RemoveAt(0)
            return $false
        }
    }

    Write-Verbose -Message (Get-DotFilesMessage -Message 'All prerequisites met.')
    return $true
}

#endregion
