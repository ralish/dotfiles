<#
    Enable/Disable the "Share with Skype" context menu entry.
#>

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param(
    [ValidateSet('Enable', 'Disable')]
    [String]$Operation
)

if (![Environment]::OSVersion.Version -eq 10) {
    throw 'Script is only valid for Windows 10.'
}

$ContextMenuPath = 'HKLM:\Software\Classes\PackagedCom\Package\Microsoft.SkypeApp_*\Class\{776DBC8D-7347-478C-8D71-791E12EF49D8}'

try {
    $ContextMenuKey = Get-ItemProperty -Path $ContextMenuPath -ErrorAction Stop
} catch {
    throw 'Failed to retrieve registry key for Skype context menu.'
}

if (!$ContextMenuKey.DllPath) {
    throw 'DllPath is empty or not-present for Skype context menu registry key.'
}

if ($Operation -eq 'Enable') {
    if ($PSCmdlet.ShouldProcess('Enable Skype context menu')) {
        if ($ContextMenuKey.DllPath.StartsWith('-')) {
            Set-ItemProperty -Path $ContextMenuPath -Name DllPath -Value ('{0}' -f $ContextMenuKey.DllPath.Substring(1))
        }
    }
} else {
    if ($PSCmdlet.ShouldProcess('Disable Skype context menu')) {
        if (!$ContextMenuKey.DllPath.StartsWith('-')) {
            Set-ItemProperty -Path $ContextMenuPath -Name DllPath -Value ('-{0}' -f $ContextMenuKey.DllPath)
        }
    }
}
