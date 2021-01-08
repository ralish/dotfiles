# Display verbose messages during profile load
#$DotFilesVerbose = $true

# Display timing data in Get-DotFilesMessage calls
#$DotFilesShowTimings = $true

# Skip expensive calls for faster profile loading
#
# - Get-Module -ListAvailable
#   Assume the module exists instead of checking
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$DotFilesFastLoad = $true

# Array of paths containing additional formatting data
#
# Calling Update-FormatData is *very* expensive. To improve profile load
# performance, functions and settings files should append the path(s) of
# any formatting data files to this array. After sourcing all functions
# and settings we'll call Update-FormatData with all specified paths.
$FormatDataPaths = [Collections.ArrayList]::new()

# Enable verbose profile load
if ($DotFilesVerbose) {
    # $VerbosePreference seems to have no value during profile load? Use
    # the default of SilentlyContinue when this appears to be the case.
    if ($VerbosePreference) {
        $VerbosePreferenceOriginal = $VerbosePreference
    } else {
        $VerbosePreferenceOriginal = 'SilentlyContinue'
    }

    $VerbosePreference = 'Continue'
}

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
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Updating formatting data ...')
    Update-FormatData -PrependPath $FormatDataPaths
}
Remove-Variable -Name FormatDataPaths

# Amend the search path to include our scripts directory
$PoshScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Scripts'
if (Test-Path -LiteralPath $PoshScriptsPath -PathType Container) {
    $env:Path = Add-PathStringElement -Path $env:Path -Element $PoshScriptsPath -Action Prepend
}
Remove-Variable -Name PoshScriptsPath

# Restore original $VerbosePreference setting
if ($DotFilesVerbose) {
    $VerbosePreference = $VerbosePreferenceOriginal
    Remove-Variable -Name 'VerbosePreferenceOriginal'
}
