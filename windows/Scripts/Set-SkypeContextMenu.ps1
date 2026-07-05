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
    $ExcMsg = 'Script is only valid for Windows 10 or later.'
    $ErrExc = [PlatformNotSupportedException]::new($ExcMsg)
    $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'OSNotSupported', $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

$ContextMenuPath = 'HKLM:\Software\Classes\PackagedCom\Package\Microsoft.SkypeApp_*\Class\{776DBC8D-7347-478C-8D71-791E12EF49D8}'
$ContextMenuKey = @(Get-ItemProperty -Path $ContextMenuPath -ErrorAction 'Ignore')

if ($ContextMenuKey.Count -ne 1) {
    if ($ContextMenuKey.Count -ne 0) {
        $ExcMsg = 'Found multiple Skype context menu registry keys.'
        $ErrExc = [InvalidOperationException]::new($ExcMsg)
        $ErrId = 'MultipleRegistryKeys'
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
    } else {
        $ExcMsg = 'Skype context menu registry key is not present.'
        $ErrExc = [Management.Automation.ItemNotFoundException]::new($ExcMsg)
        $ErrExc.ItemName = $ContextMenuPath
        $ErrExc.SessionStateCategory = [Management.Automation.SessionStateCategory]::CmdletProvider
        $ErrId = 'RegistryKeyNotFound'
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
    }

    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, $ErrId, $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

$ContextMenuKey = $ContextMenuKey[0]
if ($ContextMenuKey.PSObject.Properties.Name -contains 'DllPath') {
    if ([String]::IsNullOrWhiteSpace($ContextMenuKey.DllPath)) {
        $ExcMsg = 'DllPath registry value for Skype context menu is empty.'
        $ErrExc = [InvalidOperationException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'InvalidRegistryValue', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
} else {
    $ExcMsg = 'DllPath registry value for Skype context menu is not present.'
    $ErrExc = [Management.Automation.ItemNotFoundException]::new($ExcMsg)
    $ErrExc.ItemName = Join-Path -Path $ContextMenuPath -ChildPath 'DllPath'
    $ErrExc.SessionStateCategory = [Management.Automation.SessionStateCategory]::CmdletProvider
    $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegistryValueNotFound', $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

if ($Operation -eq 'Enable') {
    if ($PSCmdlet.ShouldProcess("${ContextMenuPath}\DllPath", 'Enable Skype context menu')) {
        if ($ContextMenuKey.DllPath.StartsWith('-')) {
            try {
                Set-ItemProperty -LiteralPath $ContextMenuKey.PSPath -Name 'DllPath' -Type 'String' -Value $ContextMenuKey.DllPath.Substring(1) -ErrorAction 'Stop'
            } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
        }
    }
} elseif ($PSCmdlet.ShouldProcess("${ContextMenuPath}\DllPath", 'Disable Skype context menu')) {
    if (!$ContextMenuKey.DllPath.StartsWith('-')) {
        try {
            Set-ItemProperty -LiteralPath $ContextMenuKey.PSPath -Name 'DllPath' -Type 'String' -Value "-$($ContextMenuKey.DllPath)" -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }
}
