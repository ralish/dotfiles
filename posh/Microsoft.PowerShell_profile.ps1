# Source custom settings
$PoshSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Settings'
if (Test-Path -Path $PoshSettingsPath -PathType Container) {
    Get-ChildItem -Path $PoshSettingsPath -File | ForEach-Object { . $_.FullName }
}
Remove-Variable -Name PoshSettingsPath

# Source custom functions
$PoshFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'
if (Test-Path -Path $PoshFunctionsPath -PathType Container) {
    Get-ChildItem -Path $PoshFunctionsPath -File | ForEach-Object { . $_.FullName }
}
Remove-Variable -Name PoshFunctionsPath

# Source custom aliases
$PoshAliasesPath = Join-Path -Path $PSScriptRoot -ChildPath 'Aliases.ps1'
if (Test-Path -Path $PoshAliasesPath -PathType Leaf) {
    . $PoshAliasesPath
}
Remove-Variable -Name PoshAliasesPath

# Amend the search path to include our scripts directory
$PoshScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Scripts'
if (Test-Path -Path $PoshScriptsPath -PathType Container) {
    $env:Path = '{0};{1}' -f $PoshScriptsPath, $env:Path
}
Remove-Variable -Name PoshScriptsPath
