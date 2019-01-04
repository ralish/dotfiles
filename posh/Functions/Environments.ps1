# Configure environment for Cygwin usage
Function Switch-Cygwin {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Cygwin',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Cygwin path is not a directory: {0}' -f $Path
    }

    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    $LocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'

    $env:Path = $env:Path |
        & $Operation -Element $LocalBinPath |
        & $Operation -Element $BinPath

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $LocalBinPath |
            & $Operation -Element $BinPath |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Node.js development
Function Switch-Nodejs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Nodejs',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Nodejs path is not a directory: {0}' -f $Path
    }

    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
    }

    $LocalNpmPath = Join-Path -Path $env:APPDATA -ChildPath 'npm'

    $env:Path = $env:Path |
        & $Operation -Element $LocalNpmPath |
        & $Operation -Element $Path

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $LocalNpmPath |
            & $Operation -Element $Path |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Perl development
Function Switch-Perl {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Perl',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Perl path is not a directory: {0}' -f $Path
    }

    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
    }

    $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
    $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
    $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'

    $env:Path = $env:Path |
        & $Operation -Element $RootBinPath |
        & $Operation -Element $SiteBinPath |
        & $Operation -Element $PerlBinPath

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $RootBinPath |
            & $Operation -Element $SiteBinPath |
            & $Operation -Element $PerlBinPath |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for PHP development
Function Switch-PHP {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\PHP',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided PHP path is not a directory: {0}' -f $Path
    }

    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
    }

    $env:Path = $env:Path |
        & $Operation -Element $Path

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $Path |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Python development
Function Switch-Python {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidatePattern('[0-9]+\.[0-9]+')]
        [String]$Version,

        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Python',

        [Switch]$Persist,
        [Switch]$Disable
    )

    $StrippedVersion = $Version -replace '\.'
    $VersionedPath = '{0}{1}' -f $Path, $StrippedVersion

    if (Test-Path -Path $VersionedPath -PathType Container) {
        $Path = $VersionedPath
    } elseif (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Python path is not a directory: {0}' -f $Path
    }

    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
    }

    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
    $LocalScriptsSharedPath = Join-Path -Path $env:APPDATA -ChildPath 'Python\Scripts'
    $LocalScriptsVersionedPath = Join-Path -Path $env:APPDATA -ChildPath ('Python\Python{0}\Scripts' -f $StrippedVersion)

    $env:Path = $env:Path |
        & $Operation -Element $LocalScriptsVersionedPath |
        & $Operation -Element $LocalScriptsSharedPath |
        & $Operation -Element $ScriptsPath |
        & $Operation -Element $Path

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $LocalScriptsVersionedPath |
            & $Operation -Element $LocalScriptsSharedPath |
            & $Operation -Element $ScriptsPath |
            & $Operation -Element $Path |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Ruby development
Function Switch-Ruby {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Ruby',

        [String]$Options='-Eutf-8',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Ruby path is not a directory: {0}' -f $Path
    }

    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'

    $env:Path = $env:Path |
        & $Operation -Element $BinPath

    if ($Options) {
        $env:RUBYOPT = $Options
    }

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $BinPath |
            Set-EnvironmentVariable -Name Path

        if ($Options) {
            Set-EnvironmentVariable -Name RUBYOPT -Value $Options
        }
    }
}
