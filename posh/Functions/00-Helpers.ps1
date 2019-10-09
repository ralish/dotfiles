# Confirm a PowerShell command is available
Function Test-CommandAvailable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name
    )

    foreach ($Command in $Name) {
        Write-Verbose -Message ('Checking command is available: {0}' -f $Command)
        if (!(Get-Command -Name $Command -ErrorAction Ignore)) {
            throw ('Required command not available: {0}' -f $Command)
        }
    }
}

# Naive check for if we're running on Windows
Function Test-IsWindows {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param()

    if ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.Platform -eq 'Win32NT') {
        return $true
    }

    return $false
}

# Confirm a PowerShell module is available
Function Test-ModuleAvailable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name,

        [ValidateSet('Boolean', 'Exception')]
        [String]$Return='Exception'
    )

    foreach ($Module in $Name) {
        Write-Verbose -Message ('Checking module is available: {0}' -f $Module)
        if (Get-Module -Name $Module -ListAvailable) {
            if ($Return -eq 'Boolean') {
                return $true
            }
        } else {
            if ($Return -eq 'Boolean') {
                return $false
            } else {
                throw ('Required module not available: {0}' -f $Module)
            }
        }
    }
}
