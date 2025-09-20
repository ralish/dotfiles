<#
    Clear Windows Live Tile cache.
#>

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param()

if (![Environment]::OSVersion.Version -eq 10) {
    throw 'Script is only valid for Windows 10 or later.'
}

$RegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ImmersiveShell\StateStore'
$ValueName = 'ResetCache'

try {
    $null = Get-ItemProperty -Path $RegPath -ErrorAction Stop
} catch {
    throw 'Failed to retrieve registry key for Windows Live Tile cache.'
}

if ($PSCmdlet.ShouldProcess("$RegPath\$ValueName", 'Set')) {
    Set-ItemProperty -Path $RegPath -Name $ValueName -Value 1
}
