<#
    Enable/Disable the "Share with Skype" context menu entry.
#>

#Requires -Version 5.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param(
    [Parameter(Mandatory)]
    [ValidateSet('Enable', 'Disable')]
    [String]$Operation
)

if ([Environment]::OSVersion.Version.Major -lt 10) {
    $ErrMsg = 'Script is only valid for Windows 10 or later.'
    $ErrCat = [Management.Automation.ErrorCategory]::NotInstalled
    $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'NotWin10OrLater', $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

$ContextMenuPath = 'HKLM:\Software\Classes\PackagedCom\Package\Microsoft.SkypeApp_*\Class\{776DBC8D-7347-478C-8D71-791E12EF49D8}'
$ContextMenuKey = Get-ItemProperty -Path $ContextMenuPath -ErrorAction 'Ignore'
if (!$ContextMenuKey.DllPath) {
    $ErrMsg = 'DllPath is empty or not-present for Skype context menu registry key.'
    $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
    $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'UnexpectedDllPathState', $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

if ($Operation -eq 'Enable') {
    if ($PSCmdlet.ShouldProcess('Enable Skype context menu')) {
        if ($ContextMenuKey.DllPath.StartsWith('-')) {
            Set-ItemProperty -Path $ContextMenuPath -Name 'DllPath' -Type 'String' -Value $ContextMenuKey.DllPath.Substring(1) -ErrorAction 'Stop'
        }
    }
} elseif ($PSCmdlet.ShouldProcess('Disable Skype context menu')) {
    if (!$ContextMenuKey.DllPath.StartsWith('-')) {
        Set-ItemProperty -Path $ContextMenuPath -Name 'DllPath' -Type 'String' -Value "-$($ContextMenuKey.DllPath)" -ErrorAction 'Stop'
    }
}
