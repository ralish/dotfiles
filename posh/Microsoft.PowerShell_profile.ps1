# Skip loading profile if PowerShell was launched with -NonInteractive
foreach ($Param in [Environment]::GetCommandLineArgs()) {
    if ($Param -ieq '-NonInteractive') {
        return
    }
}

# Display verbose messages during profile load
if (!(Get-Variable -Name DotFilesVerbose -ErrorAction Ignore)) {
    $DotFilesVerbose = $false
}

# Display timing data during profile load (requires verbose)
if (!(Get-Variable -Name DotFilesShowTImings -ErrorAction Ignore)) {
    $DotFilesShowTimings = $false
}

# Skip expensive calls for faster profile loading
#
# - Get-Module -ListAvailable
#   Assume the module exists instead of checking
if (!(Get-Variable -Name DotFilesFastLoad -ErrorAction Ignore)) {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    $DotFilesFastLoad = $true
}

# Enable verbose profile load
if ($DotFilesVerbose -or $VerbosePreference -eq 'Continue') {
    # $VerbosePreference seems to have no value during profile load? Use
    # the default of SilentlyContinue when this appears to be the case.
    if ($VerbosePreference) {
        $DotFilesVerboseOriginal = $VerbosePreference
    } else {
        $DotFilesVerboseOriginal = 'SilentlyContinue'
    }

    $VerbosePreference = 'Continue'

    # Record start of profile load
    if ($DotFilesShowTimings) {
        $DotFilesLoadStart = Get-Date
    }
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
if (Test-Path -LiteralPath $PoshFunctionsPath -PathType Container) {
    # PowerShell <= 5.1: Using -LiteralPath breaks wildcards in -Include
    Get-ChildItem -Path $PoshFunctionsPath -File -Recurse -Include '*.ps1' | ForEach-Object { . $_.FullName }
}
Remove-Variable -Name PoshFunctionsPath

# Source custom settings
$PoshSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Settings'
if (Test-Path -LiteralPath $PoshSettingsPath -PathType Container) {
    # PowerShell <= 5.1: Using -LiteralPath breaks wildcards in -Include
    Get-ChildItem -Path $PoshSettingsPath -File -Recurse -Include '*.ps1' | ForEach-Object { . $_.FullName }
}
Remove-Variable -Name PoshSettingsPath

# Update formatting data
if ($FormatDataPaths) {
    Start-DotFilesSection -Type Profile -Name Formatting
    Update-FormatData -PrependPath $FormatDataPaths
    Complete-DotFilesSection
}
Remove-Variable -Name FormatDataPaths

# Amend the search path to include scripts directory
$PoshScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Scripts'
if (Test-Path -LiteralPath $PoshScriptsPath -PathType Container) {
    $env:Path = Add-PathStringElement -Path $env:Path -Element $PoshScriptsPath -Action Prepend
}
Remove-Variable -Name PoshScriptsPath

# Clean-up specific to running in verbose mode
if ($DotFilesVerbose -or $VerbosePreference -eq 'Continue') {
    # Output total profile load time
    if ($DotFilesShowTimings) {
        $MessageParams = @{
            Message     = (Get-DotFilesTiming -StartTime $DotFilesLoadStart)
            SectionType = 'Profile'
            SectionName = 'End'
        }
        Write-Verbose -Message (Get-DotFilesMessage @MessageParams)
        Remove-Variable -Name DotFilesLoadStart, MessageParams
    }

    $VerbosePreference = $DotFilesVerboseOriginal
    Remove-Variable -Name DotFilesVerboseOriginal
}

# Clean-up profile loading functions and variables
Remove-DotFilesHelpers
