<#
    Clear Windows Live Tile cache.
#>

[CmdletBinding()]
[OutputType([Void])]
Param()

if (![Environment]::OSVersion.Version -eq 10) {
    throw 'Script is only valid for Windows 10.'
}

$RegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ImmersiveShell\StateStore'

try {
    $null = Get-ItemProperty -Path $RegPath -ErrorAction Stop
} catch {
    throw 'Failed to retrieve registry key for Windows Live Tile cache.'
}

Set-ItemProperty -Path $RegPath -Name ResetCache -Value 1
