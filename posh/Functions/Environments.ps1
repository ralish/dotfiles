if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing environment functions ...')

#region .NET

# Clear NuGet cache
Function Clear-NuGetCache {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name nuget -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear NuGet cache as nuget command not found.'
        return
    }

    $KnownCaches = @{
        HttpCache      = 'http-cache'
        GlobalPackages = 'global-packages'
        Temp           = 'temp'
        PluginsCache   = 'plugins-cache'
    }

    $NuGetLocals = & nuget locals all -List

    foreach ($Cache in $KnownCaches.Keys) {
        $CacheVar = 'NuGet{0}' -f $Cache
        $CacheRegex = '^{0}: (.*)' -f $KnownCaches[$Cache]
        $CacheFound = $false

        foreach ($Line in $NuGetLocals) {
            if ($Line -match $CacheRegex) {
                Set-Variable -Name $CacheVar -Value $Matches[1] -WhatIf:$false
                $CacheFound = $true
                break
            }
        }

        if (!$CacheFound) {
            Write-Error -Message ('Unable to determine NuGet {0} location.' -f $KnownCaches[$Cache])
            return
        }
    }

    foreach ($Cache in $KnownCaches.Keys) {
        $CachePath = Get-Variable -Name ('NuGet{0}' -f $Cache) -ValueOnly
        if ($PSCmdlet.ShouldProcess($CachePath, 'Clear')) {
            & nuget locals $KnownCaches[$Cache] -Clear -Verbosity quiet
        }
    }
}

# Update .NET tools
Function Update-DotNetTools {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Get-Command -Name dotnet -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update .NET tools as dotnet command not found.'
        return
    }

    $WriteProgressParams = @{
        Activity = 'Updating .NET tools'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    [String[]]$ListArgs = 'tool', 'list', '--global'
    [String[]]$UpdateArgs = 'tool', 'update', '--global'

    # If we're running this version of dotnet for the first time the welcome
    # banner will display. Make sure we suppress it or it'll break the regex.
    if ($env:DOTNET_NOLOGO) {
        $OriginalNoLogo = $env:DOTNET_NOLOGO
    }
    $env:DOTNET_NOLOGO = 'true'

    Write-Progress @WriteProgressParams -Status 'Enumerating .NET tools' -PercentComplete 0
    Write-Verbose -Message ('Enumerating .NET tools: dotnet {0}' -f ($ListArgs -join ' '))
    $Tools = [Collections.ArrayList]::new()
    & dotnet @ListArgs | ForEach-Object {
        if ($_ -notmatch '^(Package Id|-)' -and $_ -match '^(\S+)') {
            $null = $Tools.Add($Matches[1])
        }
    }

    $ToolsUpdated = 0
    foreach ($Tool in $Tools) {
        if ($PSCmdlet.ShouldProcess($Tool, 'Update')) {
            Write-Progress @WriteProgressParams -Status ('Updating {0}' -f $Tool) -PercentComplete ($ToolsUpdated / $Tools.Count * 90 + 10)
            Write-Verbose -Message ('Updating {0}: dotnet {1} {0}' -f $Tool, ($UpdateArgs -join ' '))
            & dotnet @UpdateArgs $Tool
            $ToolsUpdated++
        }
    }

    Write-Progress @WriteProgressParams -Completed

    # Restore the original value of the DOTNET_NOLOGO environment variable
    if ($OriginalNoLogo) {
        $env:DOTNET_NOLOGO = $OriginalNoLogo
    } else {
        $env:DOTNET_NOLOGO = $null
    }
}

#endregion

#region Go

# Clear Go cache
Function Clear-GoCache {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name go -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear Go cache as go command not found.'
        return
    }

    $GoCache = & go env GOCACHE
    if ($PSCmdlet.ShouldProcess($GoCache, 'Clear')) {
        & go clean -cache
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
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Go",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Provided Go path is not a directory: {0}' -f $Path
    }

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $Path = [IO.Path]::GetFullPath($Path)
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

        if ($GoPaths) {
            foreach ($GoPath in $GoPaths) {
                Get-EnvironmentVariable @EnvParams |
                    & $Operation @PathParams -Element $GoPath |
                    Set-EnvironmentVariable @EnvParams
            }
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $BinPath |
            Set-EnvironmentVariable @EnvParams
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

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $DepotToolsWinToolchain = 0
    } else {
        $Operation = 'Remove-PathStringElement'
        $DepotToolsWinToolchain = [String]::Empty
        $VsVersion = [String]::Empty
    }

    $Path = [IO.Path]::GetFullPath($Path)

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

# Clear Gradle cache
Function Clear-GradleCache {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if ($env:GRADLE_USER_HOME) {
        $GradleCache = Join-Path -Path $env:GRADLE_USER_HOME -ChildPath 'caches'
    } else {
        $GradleCache = Join-Path -Path $HOME -ChildPath '.gradle\caches'
    }

    if (Test-Path -Path $GradleCache -PathType Container) {
        if ($PSCmdlet.ShouldProcess($GradleCache, 'Clear')) {
            Remove-Item -Path "$GradleCache\*" -Recurse -Verbose:$false
        }
    }
}

# Clear Maven cache
Function Clear-MavenCache {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if ($env:M2_HOME) {
        $MvnRepo = Join-Path -Path $env:M2_HOME -ChildPath 'repository'
    } else {
        $MvnRepo = Join-Path -Path $HOME -ChildPath '.m2\repository'
    }

    if (Test-Path -Path $MvnRepo -PathType Container) {
        if ($PSCmdlet.ShouldProcess($MvnRepo, 'Clear')) {
            Remove-Item -Path "$MvnRepo\*" -Recurse -Verbose:$false
        }
    }
}

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

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $JavaHome = $Path
    } else {
        $Operation = 'Remove-PathStringElement'
        $JavaHome = [String]::Empty
    }

    $Path = [IO.Path]::GetFullPath($Path)
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

# Clear npm cache
Function Clear-NpmCache {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name npm -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear npm cache as npm command not found.'
        return
    }

    $NpmCache = & npm config get -g cache
    if ($PSCmdlet.ShouldProcess($NpmCache, 'Clear')) {
        & npm cache clean --force --loglevel=error
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
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Nodejs",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Provided Nodejs path is not a directory: {0}' -f $Path
    }

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $Path = [IO.Path]::GetFullPath($Path)
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
        Write-Verbose -Message ('Updating npm: npm {0} npm' -f ($UpdateArgs -join ' '))
        & npm @UpdateArgs npm
    }

    if ($PSCmdlet.ShouldProcess('Node.js packages', 'Update')) {
        Write-Verbose -Message ('Updating Node.js packages: npm {0}' -f ($UpdateArgs -join ' '))
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

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $Path = [IO.Path]::GetFullPath($Path)
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

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $Path = [IO.Path]::GetFullPath($Path)

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

# Clear pip cache
Function Clear-PipCache {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name pip -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear pip cache as pip command not found.'
        return
    }

    $PipCacheInfo = & pip cache info
    $PipCacheIndex = $null
    $PipCacheWheels = $null

    foreach ($Line in $PipCacheInfo) {
        if ($PipCacheIndex -and $PipCacheWheels) {
            break
        } elseif (!$PipCacheIndex -and $Line -match 'Package index page cache location: (.*)') {
            $PipCacheIndex = $Matches[1]
        } elseif (!$PipCacheWheels -and $Line -match 'Wheels location: (.*)') {
            $PipCacheWheels = $Matches[1]
        }
    }

    if (!$PipCacheIndex) {
        Write-Error -Message 'Unable to determine pip package index page cache location.'
        return
    }

    if (!$PipCacheWheels) {
        Write-Error -Message 'Unable to determine pip wheels cache location.'
        return
    }

    if ($PSCmdlet.ShouldProcess(('{0}, {1}' -f $PipCacheIndex, $PipCacheWheels), 'Clear')) {
        & pip cache purge -qqq
    }
}

# Configure environment for Python development
#
# Environment variables
# https://docs.python.org/3/using/cmdline.html#environment-variables
Function Switch-Python {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Python",

        [ValidatePattern('[0-9]+\.[0-9]+')]
        [String]$Version,

        [Parameter(ParameterSetName = 'Enable')]
        [ValidateSet('Dev', 'UTF-8')]
        [String[]]$Features = @('UTF-8'),

        [Switch]$Persist,

        [Parameter(ParameterSetName = 'Disable')]
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

        $Version = $PythonVersion
    }

    $NativeVersion = [Version]$Version
    $StrippedVersion = $Version -replace '\.'

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $Path = [IO.Path]::GetFullPath($Path)
    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
    $LocalScriptsSharedPath = Join-Path -Path $env:APPDATA -ChildPath 'Python\Scripts'
    $LocalScriptsVersionedPath = Join-Path -Path $env:APPDATA -ChildPath ('Python\Python{0}\Scripts' -f $StrippedVersion)

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $Path |
        & $Operation @PathParams -Element $ScriptsPath |
        & $Operation @PathParams -Element $LocalScriptsSharedPath |
        & $Operation @PathParams -Element $LocalScriptsVersionedPath

    # Python Development Mode
    if ($Features -contains 'Dev' -and $NativeVersion -ge '3.7') {
        $PythonDevMode = $true
        $env:PYTHONDEVMODE = 1
    }

    # UTF-8 Mode (see PEP 540)
    if ($Features -contains 'UTF-8' -and $NativeVersion -ge '3.7') {
        $Utf8Mode = $true
        $env:PYTHONUTF8 = 1
    }

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

        if (!$Disable) {
            if ($PythonDevMode) {
                Set-EnvironmentVariable -Name PYTHONDEVMODE -Value 1
            }

            if ($Utf8Mode) {
                Set-EnvironmentVariable -Name PYTHONUTF8 -Value 1
            }
        }
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
        Write-Verbose -Message ('Updating pip: python {0} pip' -f ($PipUpdateArgs -join ' '))
        & python @PipUpdateArgs pip
    }

    Write-Verbose -Message 'Enumerating Python packages: pipdeptree'
    $Packages = [Collections.ArrayList]::new()
    $PackageRegex = [Regex]::new('^(\S+)==')
    & pipdeptree | ForEach-Object {
        $Package = $PackageRegex.Match($_)
        if ($Package.Success) {
            $null = $Packages.Add($Package.Groups[1].Value)
        }
    }

    if ($PSCmdlet.ShouldProcess('Python packages', 'Update')) {
        Write-Verbose -Message ('Updating Python packages: pip {0} {1}' -f ($UpdateArgs -join ' '), ($Packages -join ' '))
        & pip @UpdateArgs @Packages
    }

    if (Get-Command -Name pipx -ErrorAction Ignore) {
        if ($PSCmdlet.ShouldProcess('pipx packages', 'Update')) {
            # Outputting emojis can be problematic on Windows. This isn't as big an issue as it used
            # to be, but there's still some nasty edge cases. In particular, Python will default to
            # MBCS encoding on Windows when sys.stdin and/or sys.output is redirected to a pipe.
            #
            # Enabling Python's UTF-8 Mode will resolve this issue, but it's non-default and only
            # available since Python 3.7, so just disable emojis outright as the simple workaround.
            if ($env:USE_EMOJI) {
                $UseEmoji = $env:USE_EMOJI
            }
            $env:USE_EMOJI = 0

            Write-Verbose -Message 'Updating pipx packages: pipx upgrade-all'
            & pipx upgrade-all

            if ($UseEmoji) {
                $env:USE_EMOJI = $UseEmoji
            } else {
                $env:USE_EMOJI = [String]::Empty
            }
        }
    }
}

#endregion

#region Ruby

# Clear gem cache
Function Clear-GemCache {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!(Get-Command -Name gem -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear gem cache as gem command not found.'
        return
    }

    $GemEnv = & gem env
    $GemSpecCache = $null

    foreach ($Line in $GemEnv) {
        if ($Line -match 'SPEC CACHE DIRECTORY: (.*)') {
            $GemSpecCache = $Matches[1]
            break
        }
    }

    if (!$GemSpecCache) {
        Write-Error -Message 'Unable to determine gem spec cache directory.'
        return
    }

    if ($PSCmdlet.ShouldProcess($GemSpecCache, 'Clear')) {
        & gem sources --clear-all --silent
    }
}

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

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
        $Options = [String]::Empty
    }

    $Path = [IO.Path]::GetFullPath($Path)
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
    [String[]]$CleanupArgs = 'cleanup'
    if (!$PSCmdlet.ShouldProcess('Ruby gems', 'Update')) {
        $UpdateArgs += '--explain'
        $CleanupArgs += '--dry-run'
    }

    Write-Verbose -Message ('Updating RubyGems system: gem {0} --system' -f ($UpdateArgs -join ' '))
    & gem @UpdateArgs --system

    Write-Verbose -Message ('Enumerating Ruby gems: gem {0}' -f ($ListArgs -join ' '))
    $Packages = [Collections.ArrayList]::new()
    $PackageRegex = [Regex]::new('\(default: \S+\)')
    & gem @ListArgs | ForEach-Object {
        if (!$PackageRegex.Match($_).Success) {
            $null = $Packages.Add($_.Split(' ')[0])
        }
    }

    Write-Verbose -Message ('Updating Ruby gems: gem {0} {1}' -f ($UpdateArgs -join ' '), ($Packages -join ' '))
    & gem @UpdateArgs @Packages

    Write-Verbose -Message ('Uninstalling obsolete Ruby gems: gem {0}' -f ($CleanupArgs -join ' '))
    & gem @CleanupArgs
}

#endregion
