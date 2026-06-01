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
    $ErrCat = [Management.Automation.ErrorCategory]::NotInstalled
    $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'NotWin10OrLater', $ErrCat, $null)
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
            $null = Get-Item -LiteralPath $ContextMenuPath -ErrorAction 'Stop'
        } catch {
            Write-Warning -Message "Skipping extension due to missing registry key: ${Extension}"
            continue
        }

        if ($Operation -eq 'Enable') {
            if ($PSCmdlet.ShouldProcess($Extension, 'Enable Paint 3D extension context menu')) {
                try {
                    Remove-ItemProperty -LiteralPath $ContextMenuPath -Name 'LegacyDisable' -ErrorAction 'Stop'
                } catch {
                    switch -Regex ($PSItem.FullyQualifiedErrorId) {
                        '^PathNotFound,' { }
                        Default { $PSCmdlet.WriteError($PSItem) }
                    }
                }
            }
        } elseif ($PSCmdlet.ShouldProcess($Extension, 'Disable Paint 3D extension context menu')) {
            try {
                Set-ItemProperty -LiteralPath $ContextMenuPath -Name 'LegacyDisable' -Type 'String' -Value '' -ErrorAction 'Stop'
            } catch { $PSCmdlet.WriteError($PSItem) }
        }
    }
} finally {
    if ($RemoveHKCRDrive) {
        Remove-PSDrive -Name 'HKCR' -WhatIf:$false
    }
}
