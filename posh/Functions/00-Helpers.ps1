#region Environment tests

# Confirm a command is available
Function Test-CommandAvailable {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name
    )

    foreach ($Command in $Name) {
        Write-Debug -Message ('Checking command is available: {0}' -f $Command)

        if (!(Get-Command -Name $Command -ErrorAction 'Ignore')) {
            throw 'Required command not available: {0}' -f $Command
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
        Write-Debug -Message ('Checking for environment variable: {0}' -f $EnvName)

        $EnvExpectedValue = $Environment[$EnvName]
        $EnvCurrentValue = [Environment]::GetEnvironmentVariable($EnvName)

        if (!($EnvExpectedValue -is [Boolean] -or $EnvExpectedValue -is [String])) {
            throw 'Value for key "{0}" is not a Boolean or String type.' -f $EnvName
        }

        # An empty string is an invalid environment variable value on Windows
        if ((Test-IsWindows) -and $EnvExpectedValue -is [String] -and $EnvExpectedValue -eq [String]::Empty) {
            throw 'Environment variable "{0}" cannot be set to an empty string on Windows.' -f $EnvName
        }

        if ($EnvExpectedValue -is [Boolean]) {
            # Environment variable must not exist
            if ($EnvExpectedValue -eq $false) {
                if ($null -eq $EnvCurrentValue) { continue }
                throw 'Environment variable exists: {0}' -f $EnvName
            }

            # Environment variable must exist (any value)
            if ($null -ne $EnvCurrentValue) { continue }
            throw 'Environment variable not set: {0}' -f $EnvName
        }

        if ($EnvExpectedValue -ne $EnvCurrentValue) {
            throw 'Environment variable "{0}" set to "{1}" but expected "{2}".' -f $EnvName, $EnvCurrentValue, $EnvExpectedValue
        }
    }
}

# Naive check for running on Windows
Function Test-IsWindows {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param()

    if ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.Platform -eq 'Win32NT') {
        return $true
    }

    return $false
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

    foreach ($Module in $Name) {
        Write-Debug -Message ('Checking module is available: {0}' -f $Module)

        if ($Operation -eq 'Get') {
            $ModuleAvailable = @(Get-Module -Name $Module -ListAvailable -Verbose:$false)
        } else {
            # Suppress verbose output on import
            $VerboseOriginal = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'

            try {
                Import-Module -Name $Module -ErrorAction 'Stop' -Verbose:$false
            } finally {
                # Restore the original `$VerbosePreference` setting
                $Global:VerbosePreference = $VerboseOriginal
            }

            $ModuleAvailable = @(Get-Module -Name $Module -Verbose:$false)
        }

        if ($ModuleAvailable) {
            $MissingModule = $false

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

    if ($MissingModule) {
        if ($Require -eq 'Any') {
            throw 'Suitable module not available: {0}' -f ($Name -join ', ')
        }

        throw 'Required module not available: {0}' -f $MissingModuleName
    }

    if ($PassThru) {
        return $ModuleInfo.ToArray()
    }
}

#endregion

#region Profile utilities

# Complete a `dotfiles` section and conditionally output timings
Function Complete-DotFilesSection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    Write-Debug -Message (Get-DotFilesMessage -Message 'Completing section processing ...')

    if ($DotFilesShowTimings) {
        if ($Global:DotFilesSectionStart -isnot [DateTime]) {
            throw 'No start time found for section timing.'
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

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]$SlowThresholdMs = 100,

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]$UltraSlowThresholdMs = 300
    )

    if (!$DotFilesShowTimings) { return }

    $ElapsedTime = (Get-Date) - $StartTime
    $Timing = 'Elapsed time: {0} ms' -f [Int]($ElapsedTime.TotalMilliseconds)

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
        $Path = 'Function:\{0}' -f $Helper
        Remove-Item -Path $Path
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

    if ($Platform) {
        if ($Platform -eq 'Windows' -and !(Test-IsWindows)) {
            Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping as platform is not Windows.')
            return $false
        }

        if ($Platform -eq 'Unix' -and (Test-IsWindows)) {
            Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping as platform is not Unix-like.')
            return $false
        }
    }

    if ($PwshMinVersion -and $PwshMinVersion -gt $PSVersionTable.PSVersion) {
        Write-Verbose -Message (Get-DotFilesMessage -Message ('Skipping as PowerShell version is below minimum: {0}' -f $PwshMinVersion))
        return $false
    }

    if ($PwshHostName -and $Host.Name -notin $PwshHostName) {
        Write-Verbose -Message (Get-DotFilesMessage -Message ('Skipping as PowerShell host is not supported: {0}' -f $Host.Name))
        return $false
    }

    if ($Command) {
        try {
            Test-CommandAvailable -Name $Command
        } catch {
            Write-Verbose -Message (Get-DotFilesMessage -Message $_.Exception.Message)
            $Error.RemoveAt(0)
            return $false
        }
    }

    if ($Environment) {
        try {
            Test-EnvironmentMatch -Environment $Environment
        } catch {
            Write-Verbose -Message (Get-DotFilesMessage -Message $_.Exception.Message)
            $Error.RemoveAt(0)
            return $false
        }
    }

    $ProcessModules = $ModuleOperation -eq 'Import' -or $ForceTestModule -or !$Global:DotFilesFastLoad
    if ($Module -and $ProcessModules) {
        try {
            Test-ModuleAvailable -Name $Module -Operation $ModuleOperation -Require $ModuleRequire
        } catch {
            Write-Verbose -Message (Get-DotFilesMessage -Message $_.Exception.Message)
            $Error.RemoveAt(0)
            return $false
        }
    }

    Write-Verbose -Message (Get-DotFilesMessage -Message 'All prerequisites met.')
    if ($Platform -or $Command -or $Module) { return $true }
}

#endregion
