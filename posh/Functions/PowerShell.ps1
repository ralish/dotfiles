# Invoke Format-List selecting all properties
Function fla {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject]$InputObject
    )

    Format-List -Property * @PSBoundParameters
}

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
