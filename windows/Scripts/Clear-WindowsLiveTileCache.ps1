<#
    Clear Windows Live Tile cache.
#>

#Requires -Version 5.0

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param()

if ([Environment]::OSVersion.Version.Major -lt 10) {
    $ExcMsg = 'Script is only valid for Windows 10 or later.'
    $ErrExc = [PlatformNotSupportedException]::new($ExcMsg)
    $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'OSNotSupported', $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

$RegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ImmersiveShell\StateStore'
$ValueName = 'ResetCache'

if ($PSCmdlet.ShouldProcess("${RegPath}\${ValueName}", 'Set')) {
    try {
        Set-ItemProperty -LiteralPath $RegPath -Name $ValueName -Type 'DWord' -Value 1 -ErrorAction 'Stop'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
}
