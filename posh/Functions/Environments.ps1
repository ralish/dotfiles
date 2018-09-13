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
    $PathAddition = '{0};{1}' -f $LocalBinPath, $BinPath

    Set-Item -Path Env:\Path -Value ('{0};{1}' -f $env:Path, $PathAddition)

    if ($Persist) {
        Add-EnvironmentPathElement -Name Path -Value $PathAddition
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
    $PathAddition = '{0};{1}' -f $LocalNpmPath, $Path

    Set-Item -Path Env:\Path -Value ('{0};{1}' -f $env:Path, $PathAddition)

    if ($Persist) {
        Add-EnvironmentPathElement -Name Path -Value $PathAddition
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
    $PathAddition = '{0};{1};{2}' -f $RootBinPath, $SiteBinPath, $PerlBinPath

    Set-Item -Path Env:\Path -Value ('{0};{1}' -f $env:Path, $PathAddition)

    if ($Persist) {
        Add-EnvironmentPathElement -Name Path -Value $PathAddition
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

    Set-Item -Path Env:\Path -Value ('{0};{1}' -f $env:Path, $Path)

    if ($Persist) {
        Add-EnvironmentPathElement -Name Path -Value $Path
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
    $PathAddition = '{0};{1}' -f $ScriptsPath, $Path

    Set-Item -Path Env:\Path -Value ('{0};{1}' -f $env:Path, $PathAddition)

    if ($Persist) {
        Add-EnvironmentPathElement -Name Path -Value $PathAddition
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

    Set-Item -Path Env:\Path -Value ('{0};{1}' -f $env:Path, $BinPath)
    if ($Options) {
        Set-Item -Path Env:\RUBYOPT -Value $Options
    }

    if ($Persist) {
        Add-EnvironmentPathElement -Name Path -Value $BinPath
        Set-EnvironmentVariable -Name RUBYOPT -Value $Options
    }
}
