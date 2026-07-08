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

# Paths to directories used during profile load
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$PoshCompletionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Completions'
$PoshFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'
$PoshScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Scripts'
$PoshSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Settings'
$PoshThemesPath = Join-Path -Path $PSScriptRoot -ChildPath 'Themes'

# Preferred text editors ordered by priority (space-separated)
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesPreferredEditors = 'code', 'vim', 'vi', 'nano', 'pico'

# Load opted-in components asynchronously via the idle event
$DotFilesLoadAsync = $true

# Skip certain expensive calls for faster profile loading
#
# - `Get-Module -ListAvailable`
#   Assume the module exists instead of checking.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesFastLoad = $true

# Display verbose messages during profile load
$DotFilesVerbose = $false

# Display timing data during profile load (requires verbose)
$DotFilesTimings = $false

#endregion

#region Setup

# Load the helper functions
. (Join-Path -Path $PoshFunctionsPath -ChildPath '00-Helpers.ps1')

# Indicates if we're currently executing in an async context
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$DotFilesIsAsync = $false

# Enable verbose profile loading
#
# During profile loading, how `$VerbosePreference` and related variables like
# `$DotFilesVerbose` and `$VerboseOriginal` work with scoping is not intuitive:
#
# - When initially loading the profile (i.e. PowerShell is starting), values
#   are defined and aligned across all scopes (global, script, local). This is
#   a little surprising with `$VerbosePreference` existing in the local scope.
#
# - In an asynchronous context, the variables are defined and aligned only in
#   the global and script scopes (i.e. no local scope definition). Makes sense.
#
# - When reloading the profile with verbose mode enabled (e.g. via `. up
#   -Verbose`), the behaviour is exactly the same as previously described!
#
# That last dot point sort of makes sense when you think about it, but it does
# mean it's impossible to know what the original value of `$VerbosePreference`
# was prior to reloading the profile. As it's unusual to set it to something
# other than `SilentlyContinue` in a global context, we'll just reset it to
# that after we finish (re)loading.
if ($DotFilesVerbose -or $VerbosePreference -eq 'Continue') {
    # Make sure our internal setting and `$VerbosePreference` are aligned
    $DotFilesVerbose = $true
    $VerbosePreference = 'Continue'

    Write-DotFilesMessage -Type 'Verbose' -SectionType 'Profile' -SectionName 'Begin' -Message 'Starting profile load ...'
}

# Record load time of profile and each section
if ($DotFilesTimings) {
    if ($DotFilesVerbose) {
        $DotFilesProfileStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $DotFilesProfileStopwatch.Start()

        # Reset before loading each section
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
        $DotFilesSectionStopwatch = [Diagnostics.Stopwatch]::new()
    } else {
        Write-Warning -Message 'Ignoring DotFilesTimings as DotFilesVerbose is not enabled.'
        $DotFilesTimings = $false
    }
}

# Enable async component loading
if ($DotFilesLoadAsync) {
    # Queue containing components to load asynchronously on idle events
    $AsyncLoadQueue = [Collections.Queue]::new()

    # Register the idle callback for async processing of components
    Register-EngineEvent -SourceIdentifier 'PowerShell.OnIdle' -SupportEvent -Action {
        if (Invoke-DotFilesAsyncTask) { return }
        Clear-DotFilesLoadData
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
    # Windows PowerShell 5.1: `-LiteralPath` causes `-Include` to be ignored
    #
    # An aside: the sort order returned by `Sort-Object` is different between
    # Windows PowerShell (<= 5.1) and Powershell (6+). The cause is .NET uses
    # the ICU library where possible while the .NET Framework uses Windows NLS.
    # It doesn't functionally cause any problems in our usage so is just a mild
    # annoyance. There's also no easy fix that doesn't have global effects.
    # https://learn.microsoft.com/en-au/dotnet/core/extensions/globalization-icu
    $PoshFiles = @(Get-ChildItem -Path $PoshPath -File -Recurse -Include '*.ps1' | Sort-Object -Property 'Name')

    foreach ($PoshFile in $PoshFiles) {
        if ($PoshFile.Name -eq '00-Helpers.ps1') { continue }
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

# Output final count of queued async tasks
if ($DotFilesLoadAsync) {
    $MsgParams = @{
        Type        = 'Verbose'
        SectionType = 'Profile'
        SectionName = 'End'
        Message     = "Number of queued tasks: $($AsyncLoadQueue.Count)"
    }

    Write-DotFilesMessage @MsgParams
}

# Output (synchronous) profile load time
if ($DotFilesTimings) {
    $DotFilesProfileStopwatch.Stop()

    $MsgParams = @{
        Type        = 'Verbose'
        SectionType = 'Profile'
        SectionName = 'End'
        Message     = (Get-DotFilesTiming -Stopwatch $DotFilesProfileStopwatch -SlowThresholdMs 300 -UltraSlowThresholdMs 1000)
    }

    Write-DotFilesMessage @MsgParams
}

# Signal the end of (synchronous) profile load
if ($DotFilesVerbose) {
    $MsgParams = @{
        Type        = 'Verbose'
        SectionType = 'Profile'
        SectionName = 'End'
    }

    if ($DotFilesLoadAsync) {
        Write-DotFilesMessage @MsgParams -Message 'Finished synchronous processing.'
    } else {
        Write-DotFilesMessage @MsgParams -Message 'Finished profile load.'
    }
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
