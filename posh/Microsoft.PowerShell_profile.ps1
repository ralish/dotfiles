# Skip loading profile if PowerShell was launched with -NonInteractive
foreach ($Param in [Environment]::GetCommandLineArgs()) {
    if ($Param -ieq '-NonInteractive') {
        return
    }
}

# Skip loading profile if we appear to be running in certain environments
$DotFilesSkipEnvVars = @(
    'MSBuildExtensionsPath' # MSBuild
    'VisualStudioVersion'   # Visual Studio
)
foreach ($EnvVar in $DotFilesSkipEnvVars) {
    if (Test-Path -Path Env:\$EnvVar) {
        return
    }
}
Remove-Variable -Name 'DotFilesSkipEnvVars'

# Display verbose messages during profile load
if (!(Get-Variable -Name 'DotFilesVerbose' -ErrorAction Ignore)) {
    $DotFilesVerbose = $false
}

# Display timing data during profile load (requires verbose)
if (!(Get-Variable -Name 'DotFilesShowTimings' -ErrorAction Ignore)) {
    $DotFilesShowTimings = $false
}

# Enable verbose profile load
if ($DotFilesVerbose -or $Global:VerbosePreference -eq 'Continue') {
    # $VerbosePreference seems to have no value during profile load? Use
    # the default of SilentlyContinue when this appears to be the case.
    if ($Global:VerbosePreference) {
        $DotFilesVerboseOriginal = $Global:VerbosePreference
    } else {
        $DotFilesVerboseOriginal = 'SilentlyContinue'
    }

    $Global:VerbosePreference = 'Continue'

    # Record start of profile load
    if ($DotFilesShowTimings) {
        $DotFilesLoadStart = Get-Date
    }
}

# Skip expensive calls for faster profile loading
#
# - Get-Module -ListAvailable
#   Assume the module exists instead of checking
if (!(Get-Variable -Name 'DotFilesFastLoad' -ErrorAction Ignore)) {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    $DotFilesFastLoad = $true
}

# Array of paths containing additional formatting data
#
# Calling Update-FormatData is *very* expensive. To improve profile load
# performance, functions and settings files should append the path(s) of
# any formatting data files to this array. After sourcing all functions
# and settings we'll call Update-FormatData with all specified paths.
$FormatDataPaths = [Collections.Generic.List[String]]::new()

# Source custom functions
$PoshFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'
# PowerShell <= 5.1: Using -LiteralPath breaks wildcards in -Include
Get-ChildItem -Path $PoshFunctionsPath -File -Recurse -Include '*.ps1' | ForEach-Object { . $_.FullName }
Remove-Variable -Name 'PoshFunctionsPath'

# Source custom settings
$PoshSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Settings'
# PowerShell <= 5.1: Using -LiteralPath breaks wildcards in -Include
Get-ChildItem -Path $PoshSettingsPath -File -Recurse -Include '*.ps1' | ForEach-Object { . $_.FullName }
Remove-Variable -Name 'PoshSettingsPath'

# Update formatting data
if ($FormatDataPaths) {
    Start-DotFilesSection -Type 'Profile' -Name 'Formatting'
    Update-FormatData -PrependPath $FormatDataPaths
    Complete-DotFilesSection
}
Remove-Variable -Name 'FormatDataPaths'

# Amend the search path to include scripts directory
$PoshScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Scripts'
if (Test-Path -LiteralPath $PoshScriptsPath -PathType Container) {
    $env:Path = Add-PathStringElement -Path $env:Path -Element $PoshScriptsPath -Action Prepend
}
Remove-Variable -Name 'PoshScriptsPath'

# Clean-up specific to running in verbose mode
if ($DotFilesVerbose -or $Global:VerbosePreference -eq 'Continue') {
    # Output total profile load time
    if ($DotFilesShowTimings) {
        $MessageParams = @{
            Message     = (Get-DotFilesTiming -StartTime $DotFilesLoadStart)
            SectionType = 'Profile'
            SectionName = 'End'
        }
        Write-Verbose -Message (Get-DotFilesMessage @MessageParams)
        Remove-Variable -Name 'DotFilesLoadStart', 'MessageParams'
    }

    $Global:VerbosePreference = $DotFilesVerboseOriginal
    Remove-Variable -Name 'DotFilesVerboseOriginal'
}

# Clean-up profile loading functions and variables
Remove-DotFilesHelpers
