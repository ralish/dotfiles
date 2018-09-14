# Configure environment for Cygwin usage
Function Enable-Cygwin {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Cygwin',

        [Switch]$Persist
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Cygwin path is not a directory: {0}' -f $Path
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    $LocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'

    $env:Path = $env:Path |
        Add-PathStringElement -Element $LocalBinPath |
        Add-PathStringElement -Element $BinPath

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            Add-PathStringElement -Element $LocalBinPath |
            Add-PathStringElement -Element $BinPath |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Node.js development
Function Enable-Nodejs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Nodejs',

        [Switch]$Persist
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Nodejs path is not a directory: {0}' -f $Path
    }

    $LocalNpmPath = Join-Path -Path $env:APPDATA -ChildPath 'npm'

    $env:Path = $env:Path |
        Add-PathStringElement -Element $LocalNpmPath |
        Add-PathStringElement -Element $Path

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            Add-PathStringElement -Element $LocalNpmPath |
            Add-PathStringElement -Element $Path |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Perl development
Function Enable-Perl {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Perl',

        [Switch]$Persist
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Perl path is not a directory: {0}' -f $Path
    }

    $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
    $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
    $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'

    $env:Path = $env:Path |
        Add-PathStringElement -Element $RootBinPath |
        Add-PathStringElement -Element $SiteBinPath |
        Add-PathStringElement -Element $PerlBinPath

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            Add-PathStringElement -Element $RootBinPath |
            Add-PathStringElement -Element $SiteBinPath |
            Add-PathStringElement -Element $PerlBinPath |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for PHP development
Function Enable-PHP {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\PHP',

        [Switch]$Persist
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided PHP path is not a directory: {0}' -f $Path
    }

    $env:Path = $env:Path |
        Add-PathStringElement -Element $Path

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            Add-PathStringElement -Element $Path |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Python development
Function Enable-Python {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Python',

        [Switch]$Persist
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Python path is not a directory: {0}' -f $Path
    }

    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'

    $env:Path = $env:Path |
        Add-PathStringElement -Element $ScriptsPath |
        Add-PathStringElement -Element $Path

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            Add-PathStringElement -Element $ScriptsPath |
            Add-PathStringElement -Element $Path |
            Set-EnvironmentVariable -Name Path
    }
}

# Configure environment for Ruby development
Function Enable-Ruby {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Ruby',

        [String]$Options='-Eutf-8',

        [Switch]$Persist
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Ruby path is not a directory: {0}' -f $Path
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'

    $env:Path = $env:Path |
        Add-PathStringElement -Element $BinPath

    if ($Options) {
        $env:RUBYOPT = $Options
    }

    if ($Persist) {
        Get-EnvironmentVariable -Name Path |
            Add-PathStringElement -Element $BinPath |
            Set-EnvironmentVariable -Name Path

        Set-EnvironmentVariable -Name RUBYOPT -Value $Options
    }
}
