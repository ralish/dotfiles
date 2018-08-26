Function Uninstall-ObsoleteModule {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [String[]]$Name
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $Modules = Get-InstalledModule -Name $Name
    } else {
        $Modules = Get-InstalledModule
    }

    foreach ($Module in $Modules) {
        $AllVersions = Get-InstalledModule -AllVersions -Name $Module.Name

        if ($AllVersions.Count -gt 1) {
            $AllVersions | Where-Object Version -ne $Module.Version | Uninstall-Module
        }
    }
}
