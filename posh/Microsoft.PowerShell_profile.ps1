# Source custom functions
$PoshFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'
if (Test-Path -Path $PoshFunctionsPath -PathType Container) {
    Get-ChildItem -Path $PoshFunctionsPath -File -Recurse -Include '*.ps1' | ForEach-Object { . $_.FullName }
}
Remove-Variable -Name PoshFunctionsPath

# Source custom settings
$PoshSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Settings'
if (Test-Path -Path $PoshSettingsPath -PathType Container) {
    Get-ChildItem -Path $PoshSettingsPath -File -Recurse -Include '*.ps1' | ForEach-Object { . $_.FullName }
}
Remove-Variable -Name PoshSettingsPath

# Amend the search path to include our scripts directory
$PoshScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Scripts'
if (Test-Path -Path $PoshScriptsPath -PathType Container) {
    $env:Path = '{0};{1}' -f $PoshScriptsPath, $env:Path
}
Remove-Variable -Name PoshScriptsPath

# Source profile configuration which must be run last
$PoshFinalizePath = Join-Path -Path $PSScriptRoot -ChildPath 'Finalize.ps1'
if (Test-Path -Path $PoshFinalizePath -PathType Leaf) {
    . $PoshFinalizePath
}
Remove-Variable -Name PoshFinalizePath
