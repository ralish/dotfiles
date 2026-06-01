<#
    Clear Windows Live Tile cache.
#>

#Requires -Version 5.0

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param()

if ([Environment]::OSVersion.Version.Major -lt 10) {
    $ErrMsg = 'Script is only valid for Windows 10 or later.'
    $ErrCat = [Management.Automation.ErrorCategory]::NotInstalled
    $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'NotWin10OrLater', $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

$RegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ImmersiveShell\StateStore'
$ValueName = 'ResetCache'

if ($PSCmdlet.ShouldProcess("$RegPath\$ValueName", 'Set')) {
    Set-ItemProperty -LiteralPath $RegPath -Name $ValueName -Type 'DWord' -Value 1 -ErrorAction 'Stop'
}
