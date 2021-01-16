#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
Param(
    [ValidateSet('Enable', 'Disable')]
    [String]$Operation,

    [ValidateNotNullOrEmpty()]
    [String[]]$Extensions = @('3mf', 'bmp', 'fbx', 'gif', 'glb', 'jfif', 'jpe', 'jpeg', 'jpg', 'obj', 'ply', 'png', 'stl' , 'tif', 'tiff')
)

$RemoveHKCRDrive = $false
if (!(Get-PSDrive -Name HKCR -ErrorAction Ignore)) {
    $RemoveHKCRDrive = $true
    $null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -WhatIf:$false
}

foreach ($Extension in $Extensions) {
    $Extension = $Extension.ToLower()
    $ContextMenuPath = 'HKCR:\SystemFileAssociations\.{0}\Shell\3D Edit' -f $Extension

    try {
        $null = Get-ItemProperty -Path $ContextMenuPath -ErrorAction Stop
    } catch {
        Write-Warning -Message ('Skipping extension due to missing registry key: {0}' -f $Extension)
        continue
    }

    if ($Operation -eq 'Enable') {
        if ($PSCmdlet.ShouldProcess($Extension, 'Enable Paint 3D extension context menu')) {
            Remove-ItemProperty -Path $ContextMenuPath -Name LegacyDisable -ErrorAction Ignore
        }

    } else {
        if ($PSCmdlet.ShouldProcess($Extension, 'Disable Paint 3D extension context menu')) {
            Set-ItemProperty -Path $ContextMenuPath -Name LegacyDisable -Value $null
        }
    }
}

if ($RemoveHKCRDrive) {
    Remove-PSDrive -Name HKCR -WhatIf:$false
}
