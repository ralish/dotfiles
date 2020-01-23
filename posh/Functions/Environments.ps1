Write-Verbose -Message '[dotfiles] Importing environment functions ...'

# Configure environment for Cygwin usage
Function Switch-Cygwin {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Cygwin",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Cygwin path is not a directory: {0}' -f $Path
    }

    $Params = @{ }
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
        $Params['Action'] = 'Prepend'
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    $LocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'

    $env:Path = $env:Path |
        & $Operation -Element $BinPath @Params |
        & $Operation -Element $LocalBinPath @Params

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $BinPath @Params |
            & $Operation -Element $LocalBinPath @Params |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Google (depot_tools) usage
Function Switch-Google {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$HOME\Code\Google\depot_tools",

        [Parameter(Mandatory)]
        [String]$VsVersion,

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided depot_tools path is not a directory: {0}' -f $Path
    }

    $Params = @{ }
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
        $Params['Action'] = 'Prepend'
    }

    $env:Path = $env:Path |
        & $Operation -Element $Path @Params

    $env:DEPOT_TOOLS_WIN_TOOLCHAIN = 0
    $env:GYP_MSVS_VERSION = $VsVersion

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $Path @Params |
            Set-EnvironmentVariable -Name Path

        Set-EnvironmentVariable -Name DEPOT_TOOLS_WIN_TOOLCHAIN -Value $env:DEPOT_TOOLS_WIN_TOOLCHAIN
        Set-EnvironmentVariable -Name GYP_MSVS_VERSION -Value $env:GYP_MSVS_VERSION
    }
}

# Configure environment for Node.js development
Function Switch-Nodejs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Nodejs",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Nodejs path is not a directory: {0}' -f $Path
    }

    $Params = @{ }
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
        $Params['Action'] = 'Prepend'
    }

    $LocalNpmPath = Join-Path -Path $env:APPDATA -ChildPath 'npm'

    $env:Path = $env:Path |
        & $Operation -Element $Path @Params |
        & $Operation -Element $LocalNpmPath @Params

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $Path @Params |
            & $Operation -Element $LocalNpmPath @Params |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Perl development
Function Switch-Perl {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Perl",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Perl path is not a directory: {0}' -f $Path
    }

    $Params = @{ }
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
        $Params['Action'] = 'Prepend'
    }

    $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
    $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
    $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'

    $env:Path = $env:Path |
        & $Operation -Element $PerlBinPath @Params |
        & $Operation -Element $SiteBinPath @Params |
        & $Operation -Element $RootBinPath @Params

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $PerlBinPath @Params |
            & $Operation -Element $SiteBinPath @Params |
            & $Operation -Element $RootBinPath @Params |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for PHP development
Function Switch-PHP {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\PHP",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided PHP path is not a directory: {0}' -f $Path
    }

    $Params = @{ }
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
        $Params['Action'] = 'Prepend'
    }

    $env:Path = $env:Path |
        & $Operation -Element $Path @Params

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $Path @Params |
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
        [String]$Path="$env:HOMEDRIVE\Python",

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

    $Params = @{ }
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
        $Params['Action'] = 'Prepend'
    }

    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
    $LocalScriptsSharedPath = Join-Path -Path $env:APPDATA -ChildPath 'Python\Scripts'
    $LocalScriptsVersionedPath = Join-Path -Path $env:APPDATA -ChildPath ('Python\Python{0}\Scripts' -f $StrippedVersion)

    $env:Path = $env:Path |
        & $Operation -Element $Path @Params |
        & $Operation -Element $ScriptsPath @Params |
        & $Operation -Element $LocalScriptsSharedPath @Params |
        & $Operation -Element $LocalScriptsVersionedPath @Params

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $Path @Params |
            & $Operation -Element $ScriptsPath @Params |
            & $Operation -Element $LocalScriptsSharedPath @Params |
            & $Operation -Element $LocalScriptsVersionedPath @Params |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Ruby development
Function Switch-Ruby {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Ruby",

        [String]$Options='-Eutf-8',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Ruby path is not a directory: {0}' -f $Path
    }

    $Params = @{ }
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
    } else {
        $Operation = 'Add-PathStringElement'
        $Params['Action'] = 'Prepend'
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'

    $env:Path = $env:Path |
        & $Operation -Element $BinPath @Params

    if ($Options) {
        $env:RUBYOPT = $Options
    }

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            & $Operation -Element $BinPath @Params |
            Set-EnvironmentVariable -Name Path

        if ($Options) {
            Set-EnvironmentVariable -Name RUBYOPT -Value $Options
        }
    }
}
