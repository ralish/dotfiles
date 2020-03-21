Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing environment functions ...')

# Configure environment for Cygwin usage
#
# Environment variables
# https://cygwin.com/cygwin-ug-net/setup-env.html
Function Switch-Cygwin {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Cygwin",

        [ValidateSet('Default', 'Lnk', 'Native', 'NativeStrict')]
        [String]$Symlinks='NativeStrict',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Cygwin path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    $LocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $BinPath |
        & $Operation @PathParams -Element $LocalBinPath

    $CygwinCfg = [Collections.ArrayList]@()
    if ($env:CYGWIN) {
        foreach ($Setting in $env:CYGWIN.Split(' ')) {
            if ([String]::IsNullOrEmpty($Setting)) {
                continue
            }

            if ($Setting -notmatch 'winsymlinks') {
                $null = $CygwinCfg.Add($Setting)
            }
        }
    }

    if ($Symlinks -ne 'Default') {
        $null = $CygwinCfg.Add('winsymlinks:{0}' -f $Symlinks.ToLower())
    }

    $CygwinCfg.Sort()
    $env:CYGWIN = $CygwinCfg -join ' '
    if ($env:CYGWIN) {
        Write-Host -ForegroundColor Green -Object ('Set CYGWIN environment variable to: {0}' -f $env:CYGWIN)
    }

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $LocalBinPath |
            & $Operation @PathParams -Element $BinPath |
            Set-EnvironmentVariable @EnvParams

        if (!$Disable) {
            Set-EnvironmentVariable -Name CYGWIN -Value ($CygwinCfg -join ' ')
        }
    }
}

# Configure environment for Go development
#
# Environment variables
# https://golang.org/cmd/go/#hdr-Environment_variables
Function Switch-Go {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Go",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Go path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'

    $GoPaths = @()
    if ($env:GOPATH) {
        foreach ($GoPath in $env:GOPATH.Split([IO.Path]::PathSeparator)) {
            $GoPaths += Join-Path -Path $GoPath -ChildPath 'bin'
        }
    }

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $BinPath

    if ($GoPaths) {
        foreach ($GoPath in $GoPaths) {
            $env:Path = $env:Path |
                & $Operation @PathParams -Element $GoPath
        }
    }

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $BinPath |
            Set-EnvironmentVariable @EnvParams

        if ($GoPaths) {
            foreach ($GoPath in $GoPaths) {
                Get-EnvironmentVariable @EnvParams |
                    & $Operation @PathParams -Element $GoPath |
                    Set-EnvironmentVariable @EnvParams
            }
        }
    }
}

# Configure environment for Google (depot_tools) usage
Function Switch-Google {
    [CmdletBinding(DefaultParameterSetName='Enable')]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path=('{0}\Code\Google\depot_tools' -f $HOME),

        [Parameter(ParameterSetName='Enable', Mandatory)]
        [String]$VsVersion,

        [Switch]$Persist,

        [Parameter(ParameterSetName='Disable')]
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided depot_tools path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $DepotToolsWinToolchain = 0
    } else {
        $Operation = 'Remove-PathStringElement'
        $DepotToolsWinToolchain = [String]::Empty
        $VsVersion = [String]::Empty
    }

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $Path

    $env:DEPOT_TOOLS_WIN_TOOLCHAIN = $DepotToolsWinToolchain
    $env:GYP_MSVS_VERSION = $VsVersion

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $Path |
            Set-EnvironmentVariable @EnvParams

        if (!$Disable) {
            Set-EnvironmentVariable -Name DEPOT_TOOLS_WIN_TOOLCHAIN -Value $DepotToolsWinToolchain
            Set-EnvironmentVariable -Name GYP_MSVS_VERSION -Value $VsVersion
        }
    }
}

# Configure environment for Java development
Function Switch-Java {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Java",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Java path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $JavaHome = $Path
    } else {
        $Operation = 'Remove-PathStringElement'
        $JavaHome = [String]::Empty
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $BinPath

    $env:JAVA_HOME = $JavaHome

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $BinPath |
            Set-EnvironmentVariable @EnvParams

        if (!$Disable) {
            Set-EnvironmentVariable -Name JAVA_HOME -Value $JavaHome
        }
    }
}

# Configure environment for Node.js development
#
# Environment variables
# https://nodejs.org/api/cli.html#cli_environment_variables
Function Switch-Nodejs {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Nodejs",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Nodejs path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $LocalNpmPath = Join-Path -Path $env:APPDATA -ChildPath 'npm'

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $Path |
        & $Operation @PathParams -Element $LocalNpmPath

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $LocalNpmPath |
            & $Operation @PathParams -Element $Path |
            Set-EnvironmentVariable @EnvParams
    }
}

# Configure environment for Perl development
#
# Environment variables
# https://perldoc.perl.org/perlrun.html#ENVIRONMENT
Function Switch-Perl {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Perl",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Perl path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
    $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
    $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $PerlBinPath |
        & $Operation @PathParams -Element $SiteBinPath |
        & $Operation @PathParams -Element $RootBinPath

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $RootBinPath |
            & $Operation @PathParams -Element $SiteBinPath |
            & $Operation @PathParams -Element $PerlBinPath |
            Set-EnvironmentVariable @EnvParams
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

    if (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided PHP path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $Path

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $Path |
            Set-EnvironmentVariable @EnvParams
    }
}

# Configure environment for Python development
#
# Environment variables
# https://docs.python.org/3/using/cmdline.html#environment-variables
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
    } elseif (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Python path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
    $LocalScriptsSharedPath = Join-Path -Path $env:APPDATA -ChildPath 'Python\Scripts'
    $LocalScriptsVersionedPath = Join-Path -Path $env:APPDATA -ChildPath ('Python\Python{0}\Scripts' -f $StrippedVersion)

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $Path |
        & $Operation @PathParams -Element $ScriptsPath |
        & $Operation @PathParams -Element $LocalScriptsSharedPath |
        & $Operation @PathParams -Element $LocalScriptsVersionedPath

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $LocalScriptsVersionedPath |
            & $Operation @PathParams -Element $LocalScriptsSharedPath |
            & $Operation @PathParams -Element $ScriptsPath |
            & $Operation @PathParams -Element $Path |
            Set-EnvironmentVariable @EnvParams
    }
}

# Configure environment for Ruby development
Function Switch-Ruby {
    [CmdletBinding(DefaultParameterSetName='Enable')]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path="$env:HOMEDRIVE\Ruby",

        [Parameter(ParameterSetName='Enable')]
        [String]$Options='-Eutf-8',

        [Switch]$Persist,

        [Parameter(ParameterSetName='Disable')]
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -Path $Path -PathType Container)) {
        throw 'Provided Ruby path is not a directory: {0}' -f $Path
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
        $Options = [String]::Empty
    }

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $BinPath

    $env:RUBYOPT = $Options

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $BinPath |
            Set-EnvironmentVariable @EnvParams

        if (!$Disable) {
            Set-EnvironmentVariable -Name RUBYOPT -Value $Options
        }
    }
}
