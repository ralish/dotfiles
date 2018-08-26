# Configure environment for Cygwin usage
Function Enable-Cygwin {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Cygwin'
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Cygwin path is not a directory: {0}' -f $Path
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    $LocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'
    Set-Item -Path Env:\Path -Value ('{0};{1};{2}' -f $LocalBinPath, $BinPath, $Env:PATH)
}

# Configure environment for Node.js development
Function Enable-Nodejs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Nodejs'
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Nodejs path is not a directory: {0}' -f $Path
    }

    $LocalNpmPath = Join-Path -Path $Env:APPDATA -ChildPath 'npm'
    Set-Item -Path Env:\Path -Value ('{0};{1};{2}' -f $LocalNpmPath, $Path, $Env:PATH)
}

# Configure environment for Perl development
Function Enable-Perl {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Perl'
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Perl path is not a directory: {0}' -f $Path
    }

    $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
    $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
    $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'
    Set-Item -Path Env:\Path -Value ('{0};{1};{2};{3}' -f $RootBinPath, $SiteBinPath, $PerlBinPath, $Env:PATH)
}

# Configure environment for PHP development
Function Enable-PHP {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\PHP'
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided PHP path is not a directory: {0}' -f $Path
    }

    Set-Item -Path Env:\Path -Value ('{0};{1}' -f $Path, $Env:PATH)
}

# Configure environment for Python development
Function Enable-Python {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Python'
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Python path is not a directory: {0}' -f $Path
    }

    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
    Set-Item -Path Env:\Path -Value ('{0};{1};{2}' -f $ScriptsPath, $Path, $Env:PATH)
}

# Configure environment for Ruby development
Function Enable-Ruby {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path='C:\Ruby',

        [String]$Options='-Eutf-8'
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Ruby path is not a directory: {0}' -f $Path
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    Set-Item -Path Env:\Path -Value ('{0};{1}' -f $BinPath, $Env:PATH)

    if ($Options) {
        Set-Item -Path Env:\RUBYOPT -Value $Options
    }
}
