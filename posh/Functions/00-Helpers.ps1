# Retrieve a formatted dotfiles message
Function Get-DotFilesMessage {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Message
    )

    if ($DotFilesShowTimings) {
        $CurrentTimestamp = Get-Date
        if (!$PreviousTimestamp) {
            $Global:PreviousTimestamp = $CurrentTimestamp
        }

        $ElapsedTime = $CurrentTimestamp - $PreviousTimestamp
        $Message = '[dotfiles | {0} | {1} secs] {2}' -f $CurrentTimestamp.ToString('HH:mm:ss:fff'), $ElapsedTime.TotalSeconds.ToString('F2'), $Message
        $Global:PreviousTimestamp = $CurrentTimestamp

        return $Message
    }

    return ('[dotfiles] {0}' -f $Message)
}

# Confirm a PowerShell command is available
Function Test-CommandAvailable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name
    )

    foreach ($Command in $Name) {
        Write-Debug -Message ('Checking command is available: {0}' -f $Command)
        if (!(Get-Command -Name $Command -ErrorAction Ignore)) {
            throw ('Required command not available: {0}' -f $Command)
        }
    }
}

# Naive check for if we're running on Windows
Function Test-IsWindows {
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

        [ValidateSet('Any', 'All')]
        [String]$Require = 'All',

        [Switch]$ReturnName
    )

    if ($ReturnName -and $Require -ne 'Any') {
        throw 'The ReturnName switch is only valid when Require is Any.'
    }

    foreach ($Module in $Name) {
        Write-Debug -Message ('Checking module is available: {0}' -f $Module)
        if (Get-Module -Name $Module -ListAvailable -Verbose:$false) {
            $ModuleAvailable = $true
            if ($Require -eq 'Any') {
                $ModuleAvailableName = $Module
                break
            }
        } else {
            $ModuleAvailable = $false
            $ModuleMissingName = $Module
            if ($Require -eq 'All') {
                break
            }
        }
    }

    if (!$ModuleAvailable) {
        if ($Require -eq 'Any') {
            throw ('Suitable module not available: {0}' -f [String]::Join(', ', $Name))
        } else {
            throw ('Required module not available: {0}' -f $ModuleMissingName)
        }
    }

    if ($ReturnName) {
        return $ModuleAvailableName
    }
}
