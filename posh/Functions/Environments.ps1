Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing environment functions ...')

#region .NET

# Update .NET tools
Function Update-DotNetTools {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name dotnet -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update .NET tools as dotnet command not found.'
        return
    }

    [String[]]$ListArgs = 'tool', 'list', '--global'
    [String[]]$UpdateArgs = 'tool', 'update', '--global'

    # If we're running this version of dotnet for the first time the welcome
    # banner will display. Make sure we suppress it or it'll break the regex.
    if ($env:DOTNET_NOLOGO) {
        $OriginalNoLogo = $env:DOTNET_NOLOGO
    }
    $env:DOTNET_NOLOGO = 'true'

    Write-Host -ForegroundColor Green -NoNewline 'Enumerating .NET tools: '
    Write-Host ('dotnet {0}' -f ($ListArgs -join ' '))
    $Tools = [Collections.ArrayList]::new()
    & dotnet @ListArgs | ForEach-Object {
        if ($_ -notmatch '^(Package Id|-)' -and $_ -match '^(\S+)') {
            $null = $Tools.Add($Matches[1])
        }
    }

    foreach ($Tool in $Tools) {
        if ($PSCmdlet.ShouldProcess($Tool, 'Update')) {
            Write-Host -ForegroundColor Green -NoNewline ('Updating {0}: ' -f $Tool)
            Write-Host ('dotnet {0} {1}' -f ($UpdateArgs -join ' '), $Tool)
            & dotnet @UpdateArgs $Tool
        }
    }

    # Restore the original value of the DOTNET_NOLOGO environment variable
    if ($OriginalNoLogo) {
        $env:DOTNET_NOLOGO = $OriginalNoLogo
    } else {
        $env:DOTNET_NOLOGO = $null
    }
}

#endregion

#region Cygwin

# Configure environment for Cygwin usage
#
# Environment variables
# https://cygwin.com/cygwin-ug-net/setup-env.html
Function Switch-Cygwin {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Cygwin",

        [ValidateSet('Default', 'Lnk', 'Native', 'NativeStrict')]
        [String]$Symlinks = 'NativeStrict',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
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

    $CygwinCfg = [Collections.ArrayList]::new()
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
        Write-Host -ForegroundColor Green -NoNewline 'Set CYGWIN to: '
        Write-Host $env:CYGWIN
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

#endregion

#region Go

# Configure environment for Go development
#
# Environment variables
# https://golang.org/cmd/go/#hdr-Environment_variables
Function Switch-Go {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Go",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
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

#endregion

#region Google

# Configure environment for Google (depot_tools) usage
Function Switch-Google {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = ('{0}\Code\Google\depot_tools' -f $HOME),

        [Parameter(ParameterSetName = 'Enable', Mandatory)]
        [String]$VsVersion,

        [Switch]$Persist,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
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
    if ($env:DEPOT_TOOLS_WIN_TOOLCHAIN) {
        Write-Host -ForegroundColor Green -NoNewline 'Set DEPOT_TOOLS_WIN_TOOLCHAIN to: '
        Write-Host $env:DEPOT_TOOLS_WIN_TOOLCHAIN
    }

    $env:GYP_MSVS_VERSION = $VsVersion
    if ($env:GYP_MSVS_VERSION) {
        Write-Host -ForegroundColor Green -NoNewline 'Set GYP_MSVS_VERSION to: '
        Write-Host $env:GYP_MSVS_VERSION
    }

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

#endregion

#region Java

# Configure environment for Java development
Function Switch-Java {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Java",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
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
    if ($env:JAVA_HOME) {
        Write-Host -ForegroundColor Green -NoNewline 'Set JAVA_HOME to: '
        Write-Host $env:JAVA_HOME
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

        if (!$Disable) {
            Set-EnvironmentVariable -Name JAVA_HOME -Value $JavaHome
        }
    }
}

#endregion

#region Node.js

# Configure environment for Node.js development
#
# Environment variables
# https://nodejs.org/api/cli.html#cli_environment_variables
Function Switch-Nodejs {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Nodejs",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
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

# Update Node.js packages
Function Update-NodejsPackages {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name npm -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Node.js packages as npm command not found.'
        return
    }

    [String[]]$UpdateArgs = 'update', '--global'

    if ($PSCmdlet.ShouldProcess('npm', 'Update')) {
        Write-Host -ForegroundColor Green -NoNewline 'Updating npm: '
        Write-Host ('npm {0} npm' -f ($UpdateArgs -join ' '))
        & npm @UpdateArgs npm
    }

    if ($PSCmdlet.ShouldProcess('Node.js packages', 'Update')) {
        Write-Host -ForegroundColor Green -NoNewline 'Updating Node.js packages: '
        Write-Host ('npm {0}' -f ($UpdateArgs -join ' '))
        & npm @UpdateArgs
    }
}

#endregion

#region Perl

# Configure environment for Perl development
#
# Environment variables
# https://perldoc.perl.org/perlrun.html#ENVIRONMENT
Function Switch-Perl {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Perl",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
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

#endregion

#region PHP

# Configure environment for PHP development
Function Switch-PHP {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\PHP",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
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

#endregion

#region Python

# Configure environment for Python development
#
# Environment variables
# https://docs.python.org/3/using/cmdline.html#environment-variables
Function Switch-Python {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Python",

        [ValidatePattern('[0-9]+\.[0-9]+')]
        [String]$Version,

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Provided Python path is not a directory: {0}' -f $Path
    }

    if (!$Version) {
        $PythonExe = Join-Path -Path $Path -ChildPath 'python.exe'

        try {
            $PythonVersion = & $PythonExe -V 2>&1
        } catch {
            throw ('Python binary missing or could not be executed: {0}' -f $PythonExe)
        }

        if ($PythonVersion -match '[0-9]+\.[0-9]+') {
            $PythonVersion = $Matches[0]
        } else {
            throw ('Unable to determine Python version from output: {0}' -f $PythonVersion)
        }
    }

    $StrippedVersion = $Version -replace '\.'

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

# Update Python packages
Function Update-PythonPackages {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name pipdeptree -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Python packages as pipdeptree command not found.'
        return
    }

    [String[]]$PipUpdateArgs = '-m', 'pip', 'install', '--no-python-version-warning', '--upgrade'
    [String[]]$UpdateArgs = 'install', '--no-python-version-warning', '--upgrade', '--upgrade-strategy', 'eager'

    if ($PSCmdlet.ShouldProcess('pip', 'Update')) {
        Write-Host -ForegroundColor Green -NoNewline 'Updating pip: '
        Write-Host ('python {0} pip' -f ($PipUpdateArgs -join ' '))
        & python @PipUpdateArgs pip
    }

    Write-Host -ForegroundColor Green -NoNewline 'Enumerating Python packages: '
    Write-Host 'pipdeptree'
    $Packages = [Collections.ArrayList]::new()
    $PackageRegex = [Regex]::new('^(\S+)==')
    & pipdeptree | ForEach-Object {
        $Package = $PackageRegex.Match($_)
        if ($Package.Success) {
            $null = $Packages.Add($Package.Groups[1].Value)
        }
    }

    if ($PSCmdlet.ShouldProcess('Python packages', 'Update')) {
        Write-Host -ForegroundColor Green -NoNewline 'Updating Python packages: '
        Write-Host ('pip {0} {1}' -f ($UpdateArgs -join ' '), ($Packages -join ' '))
        & pip @UpdateArgs @Packages
    }

    if (Get-Command -Name pipx -ErrorAction Ignore) {
        if ($PSCmdlet.ShouldProcess('pipx packages', 'Update')) {
            Write-Host -ForegroundColor Green -NoNewline 'Updating pipx packages: '
            Write-Host 'pipx upgrade-all'
            & pipx upgrade-all
        }
    }
}

#endregion

#region Ruby

# Configure environment for Ruby development
Function Switch-Ruby {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Ruby",

        [Parameter(ParameterSetName = 'Enable')]
        [String]$Options = '-Eutf-8',

        [Switch]$Persist,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
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
    if ($env:RUBYOPT) {
        Write-Host -ForegroundColor Green -NoNewline 'Set RUBYOPT to: '
        Write-Host $env:RUBYOPT
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

        if (!$Disable) {
            Set-EnvironmentVariable -Name RUBYOPT -Value $Options
        }
    }
}

# Update Ruby packages
Function Update-RubyGems {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name gem -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Ruby gems as gem command not found.'
        return
    }

    [String[]]$ListArgs = 'list', '--local', '--no-details'
    [String[]]$UpdateArgs = 'update', '--no-document'
    if (!$PSCmdlet.ShouldProcess('Ruby gems', 'Update')) {
        $UpdateArgs += '--explain'
    }

    Write-Host -ForegroundColor Green -NoNewline 'Enumerating Ruby gems: '
    Write-Host ('gem {0}' -f ($ListArgs -join ' '))
    $Packages = [Collections.ArrayList]::new()
    $PackageRegex = [Regex]::new('\(default: \S+\)')
    & gem @ListArgs | ForEach-Object {
        if (!$PackageRegex.Match($_).Success) {
            $null = $Packages.Add($_.Split(' ')[0])
        }
    }

    Write-Host -ForegroundColor Green -NoNewline 'Updating Ruby gems: '
    Write-Host ('gem {0} {1}' -f ($UpdateArgs -join ' '), ($Packages -join ' '))
    & gem @UpdateArgs @Packages
}

#endregion

#region Windows

# Configure environment for Windows SDK tools
Function Switch-WindowsSDK {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [ValidateNotNullOrEmpty()]
        [Version]$Version,

        [Switch]$Persist,
        [Switch]$Disable
    )

    $Win64 = [Environment]::Is64BitOperatingSystem
    if ($Win64) {
        $Architecture = 'x64'
    } else {
        $Architecture = 'x86'
    }

    if (!$Path) {
        if ($Win64) {
            $Path = "${Env:ProgramFiles(x86)}\Windows Kits"
        } else {
            $Path = "$Env:ProgramFiles\Windows Kits"
        }
    }

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Provided Windows SDK path is not a directory: {0}' -f $Path
    }

    if (!$Version) {
        $Version = [Environment]::OSVersion.Version
    }

    if ($Version -lt '10.0') {
        $SdkPath = Join-Path -Path $Path -ChildPath ('{0}\bin\{1}' -f $Version.ToString(2), $Architecture)
    } else {
        $SdkPath = Join-Path -Path $Path -ChildPath ('10\bin\{0}\{1}' -f $Version, $Architecture)
    }

    if (!$Disable -and !(Test-Path -LiteralPath $SdkPath -PathType Container)) {
        throw 'Provided Windows SDK version path is not a directory: {0}' -f $SdkPath
    }

    $PathParams = @{ }
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $SdkPath

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $SdkPath |
            & $Operation @PathParams -Element $Path |
            Set-EnvironmentVariable @EnvParams
    }
}

#endregion
