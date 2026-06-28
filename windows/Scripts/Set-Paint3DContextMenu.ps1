<#
    Enable/Disable the "Edit with Paint 3D" context menu entry.
#>

#Requires -Version 5.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param(
    [Parameter(Mandatory)]
    [ValidateSet('Enable', 'Disable')]
    [String]$Operation,

    [ValidateNotNullOrEmpty()]
    [String[]]$Extensions = @('3mf', 'bmp', 'fbx', 'gif', 'glb', 'jfif', 'jpe', 'jpeg', 'jpg', 'obj', 'ply', 'png', 'stl', 'tif', 'tiff')
)

if ([Environment]::OSVersion.Version.Major -lt 10) {
    $ErrMsg = 'Script is only valid for Windows 10 or later.'
    $ErrExc = [PlatformNotSupportedException]::new($ErrMsg)
    $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'OSNotSupported', $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

$RemoveHKCRDrive = $false
if (!(Get-PSDrive -Name 'HKCR' -ErrorAction 'Ignore')) {
    $RemoveHKCRDrive = $true
    $null = New-PSDrive -Name 'HKCR' -PSProvider 'Registry' -Root 'HKEY_CLASSES_ROOT' -WhatIf:$false
}

try {
    foreach ($Extension in $Extensions) {
        $Extension = $Extension.ToLower()
        $ContextMenuPath = "HKCR:\SystemFileAssociations\.${Extension}\Shell\3D Edit"

        try {
            # Incredibly slow as it enumerates every key as it traverses the path
            $ContextMenuKey = Get-Item -LiteralPath $ContextMenuPath -ErrorAction 'Stop'
        } catch {
            Write-Warning -Message "Skipping extension due to missing registry key: ${Extension}"
            continue
        }

        if ($Operation -eq 'Enable') {
            if ($ContextMenuKey.GetValueNames() -notcontains 'LegacyDisable') {
                Write-Verbose -Message "Context menu already enabled for extension: ${Extension}"
                continue
            }

            if ($PSCmdlet.ShouldProcess($Extension, 'Enable Paint 3D extension context menu')) {
                try {
                    Remove-ItemProperty -LiteralPath $ContextMenuPath -Name 'LegacyDisable' -ErrorAction 'Stop'
                } catch { $PSCmdlet.WriteError($PSItem) }
            }
        } else {
            if ($ContextMenuKey.GetValueNames() -contains 'LegacyDisable' -and $ContextMenuKey.GetValue('LegacyDisable').Length -eq 0) {
                Write-Verbose -Message "Context menu already disabled for extension: ${Extension}"
                continue
            }

            if ($PSCmdlet.ShouldProcess($Extension, 'Disable Paint 3D extension context menu')) {
                try {
                    Set-ItemProperty -LiteralPath $ContextMenuPath -Name 'LegacyDisable' -Type 'String' -Value '' -ErrorAction 'Stop'
                } catch { $PSCmdlet.WriteError($PSItem) }
            }
        }
    }
} finally {
    if ($RemoveHKCRDrive) {
        Remove-PSDrive -Name 'HKCR' -WhatIf:$false
    }
}
