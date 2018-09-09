# Invoke Get-Help with -Detailed
Function ghd {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Detailed @PSBoundParameters
}

# Invoke Get-Help with -Examples
Function ghe {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Examples @PSBoundParameters
}

# Invoke Get-Help with -Full
Function ghf {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Full @PSBoundParameters
}

# Uninstall obsolete versions of installed modules
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
