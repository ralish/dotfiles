#region Skip load

# Skip loading profile if PowerShell was launched with `-NonInteractive`
foreach ($CmdLineArg in [Environment]::GetCommandLineArgs()) {
    if ($CmdLineArg -ieq '-NonInteractive') {
        Remove-Variable -Name 'CmdLineArg'
        return
    }
}

# Environment variables indicating a specific environment type
$DotFilesSkipEnvVars = @(
    'MSBuildExtensionsPath' # MSBuild
    'VisualStudioVersion'   # Visual Studio
)

# Skip loading profile if we appear to be running in a listed environment
foreach ($SkipEnvVar in $DotFilesSkipEnvVars) {
    if (Test-Path -LiteralPath "Env:\${SkipEnvVar}") {
        Remove-Variable -Name 'DotFilesSkipEnvVars', 'SkipEnvVar'
        return
    }
}

#endregion

#region Configuration

# Display verbose messages during profile load
$DotFilesVerbose = $false

# Display timing data during profile load (requires verbose)
$DotFilesTimings = $false

# Skip certain expensive calls for faster profile loading
#
# - `Get-Module -ListAvailable`
#   Assume the module exists instead of checking.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesFastLoad = $true

# Load opted-in components asynchronously via the idle event
$DotFilesLoadAsync = $true

# Paths to directories used during profile load
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$PoshCompletionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Completions'
$PoshFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'
$PoshScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Scripts'
$PoshSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Settings'

#endregion

#region Setup

# Load the helper functions
. (Join-Path -Path $PoshFunctionsPath -ChildPath '00-Helpers.ps1')

# Enable verbose profile load
if ($DotFilesVerbose -or $Global:VerbosePreference -eq 'Continue') {
    # `$VerbosePreference` seems to have no value during profile load? Use
    # the default of `SilentlyContinue` when this appears to be the case.
    if ($Global:VerbosePreference) {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $DotFilesVerboseOriginal = $Global:VerbosePreference
    } else {
        $DotFilesVerboseOriginal = 'SilentlyContinue'
    }

    $Global:VerbosePreference = 'Continue'
}

# Record load time of profile and each section
if ($DotFilesTimings) {
    if ($DotFilesVerbose) {
        $DotFilesProfileStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $DotFilesProfileStopwatch.Start()

        # Reset before loading each section
        $DotFilesSectionStopwatch = [Diagnostics.Stopwatch]::StartNew()
    } else {
        Write-Warning -Message 'Ignoring DotFilesTimings as DotFilesVerbose is not enabled.'
        $DotFilesTimings = $false
    }
}

# Indicates if we're currently executing in an async context
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesIsAsync = $false

# Enable async component loading
if ($DotFilesLoadAsync) {
    # Queue containing components to load asynchronously on idle events
    $AsyncLoadQueue = [Collections.Queue]::new()

    # Register the idle callback for async processing of components
    Register-EngineEvent -SourceIdentifier 'PowerShell.OnIdle' -SupportEvent -Action {
        if ($AsyncLoadQueue.Count -gt 0) {
            & $AsyncLoadQueue.Dequeue()
            return
        }

        Clear-DotFilesLoadData

        Write-DotFilesMessage -Type 'Debug' -Message 'Unregistering idle event callback ...'
        Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force
    }
}

# Array of paths containing additional formatting data
#
# Calling `Update-FormatData` is *very* expensive. To improve profile load
# performance, functions and settings files should append the path(s) of
# any formatting data files to this array. After sourcing all functions
# and settings we'll call `Update-FormatData` with all specified paths.
$FormatDataPaths = [Collections.Generic.List[String]]::new()

#endregion

#region Processing

# Source functions and settings
foreach ($PoshPath in $PoshFunctionsPath, $PoshSettingsPath) {
    # PowerShell <= 5.1: Using `-LiteralPath` breaks wildcards in `-Include`
    $PoshFiles = @(Get-ChildItem -Path $PoshPath -File -Recurse -Include '*.ps1' | Sort-Object -Property 'Name')

    foreach ($PoshFile in $PoshFiles) {
        if ($PoshFile.Name -eq '00-Helpers.ps1') { continue }

        if ($DotFilesTimings) {
            $DotFilesSectionStopwatch.Restart()
        }

        . $PoshFile.FullName
    }
}

# Update formatting data
if ($FormatDataPaths) {
    $null = Start-DotFilesSection -Type 'Profile' -Name 'Formatting'
    Update-FormatData -PrependPath $FormatDataPaths
    Complete-DotFilesSection
}

# Amend the search path to include scripts directory
if (Test-Path -LiteralPath $PoshScriptsPath -PathType 'Container') {
    $Env:Path = Add-PathStringElement -Path $Env:Path -Element $PoshScriptsPath -Action 'Prepend'
}

# Output (synchronous) profile load time
if ($DotFilesTimings) {
    $DotFilesProfileStopwatch.Stop()

    $MsgParams = @{
        Type        = 'Verbose'
        Message     = (Get-DotFilesTiming -Stopwatch $DotFilesProfileStopwatch -SlowThresholdMs 300 -UltraSlowThresholdMs 1000)
        SectionType = 'Profile'
        SectionName = 'End'
    }

    Write-DotFilesMessage @MsgParams
}

#endregion

#region Clean-up

# Clean-up ephemeral variables (not required for async)
Remove-Variable -Name @(
    'DotFilesSkipEnvVars'
    'PoshFunctionsPath'
    'PoshScriptsPath'
    'PoshSettingsPath'

    'CmdLineArg'
    'MsgParams'
    'PoshFile'
    'PoshFiles'
    'PoshPath'
    'SkipEnvVar'

    'foreach'
    'switch'
) -ErrorAction 'Ignore'

# Clean-up profile loading data (performed later if using async)
if (!$DotFilesLoadAsync) {
    Clear-DotFilesLoadData
}

#endregion
