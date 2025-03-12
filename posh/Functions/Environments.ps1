Start-DotFilesSection -Type 'Functions' -Name 'Environments'

#region .NET

# Clear NuGet cache
Function Clear-NuGetCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'nuget' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear NuGet cache as nuget command not found.'
        return
    }

    $KnownCaches = @{
        HttpCache      = 'http-cache'
        GlobalPackages = 'global-packages'
        Temp           = 'temp'
        PluginsCache   = 'plugins-cache'
    }

    [String[]]$GetArgs = 'locals', 'all', '-list'
    [String[]]$ClearArgs = '-clear', '-verbosity', 'quiet'

    Write-Verbose -Message ('Enumerating NuGet caches: nuget {0}' -f ($GetArgs -join ' '))
    $NuGetLocals = & nuget @GetArgs

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
            throw 'Unable to determine NuGet {0} location.' -f $KnownCaches[$Cache]
        }
    }

    foreach ($Cache in $KnownCaches.Keys) {
        $CachePath = Get-Variable -Name ('NuGet{0}' -f $Cache) -ValueOnly
        if ($PSCmdlet.ShouldProcess($CachePath, 'Clear')) {
            Write-Verbose -Message ('Clearing {0} cache: nuget locals {0} {1}' -f $Cache, ($ClearArgs -join ' '))
            & nuget locals $KnownCaches[$Cache] @ClearArgs
        }
    }
}

# Update .NET tools
Function Update-DotNetTools {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Get-Command -Name 'dotnet' -ErrorAction Ignore)) {
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

    # .NET 8.0.400 added the "--all" parameter to update all tools, but it was
    # effectively broken until the 8.0.403 release. For details see the issue:
    # https://github.com/dotnet/sdk/issues/42598
    #
    # For earlier releases we enumerate the installed tools and update each
    # individually.
    $CliVersion = [Version](& dotnet --version)
    if ($CliVersion -ge '8.0.403') {
        $UpdateArgs += '--all'
        Write-Verbose -Message ('Updating .NET tools: dotnet {0}' -f ($UpdateArgs -join ' '))
        & dotnet @UpdateArgs
    } else {
        $WriteProgressParams = @{
            Activity = 'Updating .NET tools'
        }

        if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
            $WriteProgressParams['ParentId'] = $ProgressParentId
            $WriteProgressParams['Id'] = $ProgressParentId + 1
        }

        Write-Progress @WriteProgressParams -Status 'Enumerating .NET tools' -PercentComplete 1
        Write-Verbose -Message ('Enumerating .NET tools: dotnet {0}' -f ($ListArgs -join ' '))
        $Tools = [Collections.Generic.List[String]]::new()
        & dotnet @ListArgs | ForEach-Object {
            if ($_ -notmatch '^(Package Id|-)' -and $_ -match '^(\S+)') {
                $Tools.Add($Matches[1])
            }
        }

        $ToolsUpdated = 0
        foreach ($Tool in $Tools) {
            Write-Progress @WriteProgressParams -Status ('Updating {0}' -f $Tool) -PercentComplete ($ToolsUpdated / $Tools.Count * 90 + 10)
            if ($PSCmdlet.ShouldProcess($Tool, 'Update')) {
                Write-Verbose -Message ('Updating {0}: dotnet {1} {0}' -f $Tool, ($UpdateArgs -join ' '))
                & dotnet @UpdateArgs $Tool
                $ToolsUpdated++
            }
        }

        Write-Progress @WriteProgressParams -Completed
    }

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
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'go' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear Go caches as go command not found.'
        return
    }

    [String[]]$BuildGetArgs = 'env', 'GOCACHE'
    [String[]]$ModuleGetArgs = 'env', 'GOMODCACHE'

    [String[]]$BuildClearArgs = 'clean', '-cache'
    [String[]]$ModuleClearArgs = 'clean', '-modcache'

    Write-Verbose -Message ('Determining Go build cache path: go {0}' -f ($BuildGetArgs -join ' '))
    $GoBuildCache = & go @BuildGetArgs

    Write-Verbose -Message ('Determining Go module cache path: go {0}' -f ($ModuleGetArgs -join ' '))
    $GoModuleCache = & go @ModuleGetArgs

    if ($PSCmdlet.ShouldProcess($GoBuildCache, 'Clear')) {
        Write-Verbose -Message ('Clearing Go build cache: go {0}' -f ($BuildClearArgs -join ' '))
        & go @BuildClearArgs
    }

    if ($PSCmdlet.ShouldProcess($GoModuleCache, 'Clear')) {
        Write-Verbose -Message ('Clearing Go module cache: go {0}' -f ($ModuleClearArgs -join ' '))
        & go @ModuleClearArgs
    }
}

# Configure environment for Go development
#
# Environment variables
# https://golang.org/cmd/go/#hdr-Environment_variables
#
# Input environment variables
# - GOPATH (optional)
#   Each path is added to the PATH environment variable.
Function Switch-Go {
    [CmdletBinding()]
    [OutputType([Void])]
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
            if (![IO.Path]::IsPathFullyQualified($GoPath)) {
                Write-Warning -Message ('Skipping path in GOPATH which is not fully qualified: {0}' -f $GoPath)
                continue
            }
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

# Update Go executable packages installed by "go install"
Function Update-GoExecutables {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'gup' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Go executables as gup command not found.'
        return
    }

    $GupExecName = 'gup'
    if (Test-IsWindows) {
        $GupExecName = '{0}.exe' -f $GupExecName
    }

    $GupOperation = 'update'
    if (!$PSCmdlet.ShouldProcess('gup', 'Update')) {
        $GupOperation = 'check'
    }

    Write-Verbose -Message ('Updating gup: gup {0} {1}' -f $GupOperation, $GupExecName)
    & gup $GupOperation $GupExecName

    $GupOperation = 'update'
    if (!$PSCmdlet.ShouldProcess('Go executables', 'Update')) {
        $GupOperation = 'check'
    }

    Write-Verbose -Message ('Updating Go executables: gup {0}' -f $GupOperation)
    & gup $GupOperation
}

#endregion

#region Google

# Configure environment for Google depot_tools usage
Function Switch-GoogleDepotTools {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [Parameter(ParameterSetName = 'Enable', Mandatory)]
        [String]$VsVersion,

        [Switch]$Persist,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$Disable
    )

    if (!$PSBoundParameters['Path']) {
        $Path = Join-Path -Path $Code -ChildPath 'Google\depot_tools'
    }

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
            Set-EnvironmentVariable -Name 'DEPOT_TOOLS_WIN_TOOLCHAIN' -Value $DepotToolsWinToolchain
            Set-EnvironmentVariable -Name 'GYP_MSVS_VERSION' -Value $VsVersion
        }
    }
}

#endregion

#region Java

# Clear Gradle cache
#
# Input environment variables
# - GRADLE_USER_HOME (optional)
#   Used to determine the "caches" path instead of the default path.
Function Clear-GradleCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if ($env:GRADLE_USER_HOME) {
        if (![IO.Path]::IsPathFullyQualified($env:GRADLE_USER_HOME)) {
            throw 'GRADLE_USER_HOME is set but is not a fully qualified path: {0}' -f $env:GRADLE_USER_HOME
        }
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
    [OutputType([Void])]
    Param()

    if (!(Get-Command -Name 'mvn' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear Maven cache as mvn command not found.'
        return
    }

    [String[]]$GetArgs = 'help:evaluate', '-q', '-Dexpression=settings.localRepository', '-DforceStdout'

    Write-Verbose -Message ('Determining mvn cache path: mvn {0}' -f ($GetArgs -join ' '))
    $MvnCache = & mvn @GetArgs

    if (Test-Path -Path $MvnCache -PathType Container) {
        if ($PSCmdlet.ShouldProcess($MvnCache, 'Clear')) {
            Remove-Item -Path "$MvnCache\*" -Recurse -Verbose:$false
        }
    }
}

# Configure environment for Java development
Function Switch-Java {
    [CmdletBinding()]
    [OutputType([Void])]
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
            Set-EnvironmentVariable -Name 'JAVA_HOME' -Value $JavaHome
        }
    }
}

#endregion

#region Node.js

# Clear npm cache
Function Clear-NpmCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'npm' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear npm cache as npm command not found.'
        return
    }

    [String[]]$GetArgs = 'config', 'get', '-g', 'cache'
    [String[]]$ClearArgs = 'cache', 'clean', '--force', '--loglevel=error'

    Write-Verbose -Message ('Determining npm cache path: npm {0}' -f ($GetArgs -join ' '))
    $NpmCache = & npm @GetArgs

    if ($PSCmdlet.ShouldProcess($NpmCache, 'Clear')) {
        Write-Verbose -Message ('Clearing npm cache: npm {0}' -f ($ClearArgs -join ' '))
        & npm @ClearArgs
    }
}

# Configure environment for Node.js development
#
# Environment variables
# https://nodejs.org/api/cli.html#cli_environment_variables
#
# Input environment variables
# - NPM_CONFIG_PREFIX (optional)
#   Added to the PATH environment variable instead of the default path.
Function Switch-Nodejs {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Nodejs",

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Provided Node.js path is not a directory: {0}' -f $Path
    }

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    if ($env:NPM_CONFIG_PREFIX) {
        if (![IO.Path]::IsPathFullyQualified($env:NPM_CONFIG_PREFIX)) {
            throw 'NPM_CONFIG_PREFIX is set but is not a fully qualified path: {0}' -f $env:NPM_CONFIG_PREFIX
        }
        $GlobalNpmPath = $env:NPM_CONFIG_PREFIX
    } else {
        $GlobalNpmPath = Join-Path -Path $env:APPDATA -ChildPath 'npm'
    }

    $Path = [IO.Path]::GetFullPath($Path)

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $Path |
        & $Operation @PathParams -Element $GlobalNpmPath

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $GlobalNpmPath |
            & $Operation @PathParams -Element $Path |
            Set-EnvironmentVariable @EnvParams
    }
}

# Update Node.js packages
Function Update-NodejsPackages {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'npm' -ErrorAction Ignore)) {
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
#
# Input environment variables
# - PERL5LIB (optional)
#   Used to determine the user install path instead of the default path.
Function Switch-Perl {
    [CmdletBinding()]
    [OutputType([Void])]
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

    if ($env:PERL5LIB) {
        if (![IO.Path]::IsPathFullyQualified($env:PERL5LIB)) {
            throw 'PERL5LIB is set but is not a fully qualified path: {0}' -f $env:PERL5LIB
        }

        $UserBasePathElements = $env:PERL5LIB.Split([IO.Path]::DirectorySeparatorChar)
        if ($UserBasePathElements.Count -lt 3) {
            throw 'PERL5LIB has less path components than expected: {0}' -f $env:PERL5LIB
        }

        $UserBasePath = [String]::Join([IO.Path]::DirectorySeparatorChar, $UserBasePathElements[0..($UserBasePathElements.Count - 3)])

        $UserBasePathEsc = $UserBasePath
        if ([IO.Path]::DirectorySeparatorChar -eq '\') {
            $UserBasePathEsc = $UserBasePath.Replace('\', '\\')
        }
    }

    $Path = [IO.Path]::GetFullPath($Path)
    if ($env:PERL5LIB) {
        $UserBinPath = Join-Path -Path $UserBasePath -ChildPath 'bin'
    }
    $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
    $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
    $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'

    if ($env:PERL5LIB) {
        $env:Path = $env:Path |
            & $Operation @PathParams -Element $UserBinPath
    }

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $PerlBinPath |
        & $Operation @PathParams -Element $SiteBinPath |
        & $Operation @PathParams -Element $RootBinPath

    if ($env:PERL5LIB) {
        # Extra options for Module::Build
        if ($Disable) {
            $env:PERL_MB_OPT = $null
        } else {
            $env:PERL_MB_OPT = '--install_base "{0}"' -f $UserBasePathEsc
        }
        Write-Host -ForegroundColor Green -NoNewline 'Set PERL_MB_OPT to: '
        Write-Host $env:PERL_MB_OPT

        # Extra options for ExtUtils::MakeMaker
        if ($Disable) {
            $env:PERL_MM_OPT = $null
        } else {
            $env:PERL_MM_OPT = 'INSTALL_BASE="{0}"' -f $UserBasePathEsc
        }
        Write-Host -ForegroundColor Green -NoNewline 'Set PERL_MM_OPT to: '
        Write-Host $env:PERL_MM_OPT
    }

    if ($Persist) {
        $EnvParams = @{
            Name = 'Path'
        }

        if (!$Disable) {
            $PathParams['Action'] = 'Append'
        }

        if ($env:PERL5LIB) {
            Get-EnvironmentVariable @EnvParams |
                & $Operation @PathParams -Element $UserBinPath |
                Set-EnvironmentVariable @EnvParams
        }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $RootBinPath |
            & $Operation @PathParams -Element $SiteBinPath |
            & $Operation @PathParams -Element $PerlBinPath |
            Set-EnvironmentVariable @EnvParams

        if (!$Disable) {
            if ($env:PERL5LIB) {
                Set-EnvironmentVariable -Name 'PERL_MB_OPT' -Value $env:PERL_MB_OPT
                Set-EnvironmentVariable -Name 'PERL_MM_OPT' -Value $env:PERL_MM_OPT
            }
        }
    }
}

#endregion

#region PHP

# Configure environment for PHP development
Function Switch-PHP {
    [CmdletBinding()]
    [OutputType([Void])]
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
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'pip' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear pip cache as pip command not found.'
        return
    }

    [String[]]$GetArgs = 'cache', 'info'
    [String[]]$ClearArgs = 'cache', 'purge', '-qqq'

    $PipVersionRaw = (& pip --version) -join [String]::Empty
    if ($PipVersionRaw -notmatch '^pip ([0-9]+\.[0-9]+(\.[0-9]+)?)') {
        throw 'Unable to determine pip package version.'
    }

    $PipVersion = [Version]$Matches[1]
    $PipSupportsCacheIndexV2 = $PipVersion -ge '23.3'

    Write-Verbose -Message ('Determining pip cache path: pip {0}' -f ($GetArgs -join ' '))
    $PipCacheInfo = & pip @GetArgs

    $PipCachePaths = [Collections.Generic.List[String]]::new()
    $PipCacheIndex = $false
    $PipCacheWheels = $false
    $PipCacheIndexV2 = !$PipSupportsCacheIndexV2

    foreach ($Line in $PipCacheInfo) {
        if ($Line -match '^Package index page cache location(?: \(older pips\))?: (.*)') {
            $PipCacheIndex = $true
        } elseif ($Line -match '^(?:Locally built )?wheels location: (.*)') {
            $PipCacheWheels = $true
        } elseif ($PipSupportsCacheIndexV2 -and $Line -match '^Package index page cache location \(pip v23\.3\+\): (.*)') {
            $PipCacheIndexV2 = $true
        } else {
            continue
        }

        $PipCachePaths.Add($Matches[1])
        if ($PipCacheIndex -and $PipCacheWheels -and $PipCacheIndexV2) {
            break
        }
    }

    if (!$PipCacheIndexV2) {
        throw 'Unable to determine pip package index page cache v2 location.'
    }

    if (!$PipCacheIndex) {
        throw 'Unable to determine pip package index page cache location.'
    }

    if (!$PipCacheWheels) {
        throw 'Unable to determine pip wheels cache location.'
    }

    if ($PSCmdlet.ShouldProcess($PipCachePaths -join ', ', 'Clear')) {
        Write-Verbose -Message ('Clearing pip cache: pip {0}' -f ($ClearArgs -join ' '))
        & pip @ClearArgs
    }
}

# Configure environment for Python development
#
# Environment variables
# https://docs.python.org/3/using/cmdline.html#environment-variables
#
# Input environment variables
# - PYTHONUSERBASE (optional)
#   Used to determine the user install path instead of the default path.
Function Switch-Python {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
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
            throw 'Python binary missing or could not be executed: {0}' -f $PythonExe
        }

        if ($PythonVersion -match '[0-9]+\.[0-9]+') {
            $PythonVersion = $Matches[0]
        } else {
            throw 'Unable to determine Python version from output: {0}' -f $PythonVersion
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

    if ($env:PYTHONUSERBASE) {
        if (![IO.Path]::IsPathFullyQualified($env:PYTHONUSERBASE)) {
            throw 'PYTHONUSERBASE is set but is not a fully qualified path: {0}' -f $env:PYTHONUSERBASE
        }
        $PythonUserBase = $env:PYTHONUSERBASE
    } else {
        $PythonUserBase = $env:APPDATA
    }

    $Path = [IO.Path]::GetFullPath($Path)
    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
    $LocalScriptsSharedPath = Join-Path -Path $PythonUserBase -ChildPath 'Python\Scripts'
    $LocalScriptsVersionedPath = Join-Path -Path $PythonUserBase -ChildPath ('Python\Python{0}\Scripts' -f $StrippedVersion)

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $Path |
        & $Operation @PathParams -Element $ScriptsPath |
        & $Operation @PathParams -Element $LocalScriptsSharedPath |
        & $Operation @PathParams -Element $LocalScriptsVersionedPath

    # Python Development Mode
    if ($Features -contains 'Dev' -and $NativeVersion -ge '3.7') {
        $PythonDevMode = $true
        $env:PYTHONDEVMODE = 1
        Write-Host -ForegroundColor Green -NoNewline 'Set PYTHONDEVMODE to: '
        Write-Host $env:PYTHONDEVMODE
    }

    # UTF-8 Mode (see PEP 540)
    if ($Features -contains 'UTF-8' -and $NativeVersion -ge '3.7') {
        $Utf8Mode = $true
        $env:PYTHONUTF8 = 1
        Write-Host -ForegroundColor Green -NoNewline 'Set PYTHONUTF8 to: '
        Write-Host $env:PYTHONUTF8
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
                Set-EnvironmentVariable -Name 'PYTHONDEVMODE' -Value 1
            }

            if ($Utf8Mode) {
                Set-EnvironmentVariable -Name 'PYTHONUTF8' -Value 1
            }
        }
    }
}

# Update Python packages
Function Update-PythonPackages {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    $UpdatePipPackages = $false
    if (!(Get-Command -Name 'pip' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Python packages as pip command not found.'
    } elseif (!(Get-Command -Name 'pipdeptree' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Python packages as pipdeptree command not found.'
    } elseif (!((Test-IsWindows) -or ![String]::IsNullOrWhiteSpace($env:VIRTUAL_ENV))) {
        Write-Warning -Message 'Skipping update of Python packages as not in a virtualenv.'
    } else {
        $UpdatePipPackages = $true
    }

    if ($UpdatePipPackages) {
        [String[]]$UpdateArgs = 'install', '--upgrade', '--upgrade-strategy', 'eager'
        [String[]]$PipUpdateArgs = '-m', 'pip', 'install', '--upgrade'

        $PipVersionRaw = (& pip --version) -join [String]::Empty
        if ($PipVersionRaw -notmatch '^pip ([0-9]+\.[0-9]+(\.[0-9]+)?)') {
            throw 'Unable to determine pip package version.'
        }

        $PipVersion = [Version]$Matches[1]
        if ($PipVersion -lt '25.0') {
            $UpdateArgs += '--no-python-version-warning'
            $PipUpdateArgs += '--no-python-version-warning'
        }

        if ($PSCmdlet.ShouldProcess('pip', 'Update')) {
            Write-Verbose -Message ('Updating pip: python {0} pip' -f ($PipUpdateArgs -join ' '))
            & python @PipUpdateArgs pip
        }

        Write-Verbose -Message 'Enumerating Python packages: pipdeptree'
        $Packages = [Collections.Generic.List[String]]::new()
        $PackageRegex = [Regex]::new('^(\S+)==')
        & pipdeptree | ForEach-Object {
            $Package = $PackageRegex.Match($_)
            if ($Package.Success) {
                $Packages.Add($Package.Groups[1].Value)
            }
        }

        if ($PSCmdlet.ShouldProcess('Python packages', 'Update')) {
            Write-Verbose -Message ('Updating Python packages: pip {0} {1}' -f ($UpdateArgs -join ' '), ($Packages -join ' '))
            & pip @UpdateArgs @Packages
        }
    }

    if (Get-Command -Name 'pipx' -ErrorAction Ignore) {
        [String[]]$PipxUpdateArgs = 'upgrade-all'

        if ($PSCmdlet.ShouldProcess('pipx packages', 'Update')) {
            # Outputting emojis can be problematic on Windows. This isn't as
            # big an issue as it used to be, but there's still some nasty edge
            # cases. In particular, Python will default to MBCS encoding on
            # Windows when sys.stdin and/or sys.output is redirected to a pipe.
            #
            # Enabling Python's UTF-8 Mode will resolve this issue, but it's
            # non-default and only available since Python 3.7, so just disable
            # emojis outright as the simple workaround.
            if ($env:USE_EMOJI) {
                $UseEmoji = $env:USE_EMOJI
            }
            $env:USE_EMOJI = 0

            Write-Verbose -Message ('Updating pipx packages: pipx {0}' -f ($PipxUpdateArgs -join ' '))
            & pipx @PipxUpdateArgs

            if ($UseEmoji) {
                $env:USE_EMOJI = $UseEmoji
            } else {
                $env:USE_EMOJI = [String]::Empty
            }
        }
    }
}

#endregion

#region Qt

# Update Qt components
Function Update-QtComponents {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param(
        [String[]]$AutoAnswer = 'AssociateCommonFiletypes=No'
    )

    DynamicParam {
        $PathAttrCollection = [Collections.ObjectModel.Collection[Attribute]]::new()
        $PathParamAttr = [Management.Automation.ParameterAttribute]::new()

        if (Test-IsWindows) {
            $ValidateNotNullOrEmptyAttr = [Management.Automation.ValidateNotNullOrEmptyAttribute]::new()
            $PathAttrCollection.Add($ValidateNotNullOrEmptyAttr)
        } else {
            $PathParamAttr.Mandatory = $true
        }

        $PathAttrCollection.Add($PathParamAttr)
        $PathParam = [Management.Automation.RuntimeDefinedParameter]::new(
            'Path', [String], $PathAttrCollection
        )

        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
        $RuntimeParams.Add('Path', $PathParam)

        return $RuntimeParams
    }

    Begin {
        if (!$PSBoundParameters['Path'] -and (Test-IsWindows)) {
            $PSBoundParameters['Path'] = '{0}\DevEnvs\Qt\MaintenanceTool.exe' -f $env:HOMEDRIVE
        }
    }

    End {
        $QtMtName = 'MaintenanceTool'
        if (Test-IsWindows) {
            $QtMtName = '{0}.exe' -f $QtMtName
        }

        $QtMtPath = Get-Item -LiteralPath $PSBoundParameters['Path'] -ErrorAction Ignore
        if ($QtMtPath -is [IO.DirectoryInfo]) {
            $QtMtPath = Join-Path -Path $QtMtPath.FullName -ChildPath $QtMtName
            $QtMtPath = Get-Item -LiteralPath $QtMtPath -ErrorAction Ignore
        }

        if ($QtMtPath -isnot [IO.FileInfo] -or $QtMtPath.Name -ne $QtMtName) {
            Write-Error -Message 'Unable to update Qt components as MaintenanceTool command was not found.'
            return
        }

        $QtMtArgs = 'update', '--accept-licenses', '--confirm-command'
        if ($AutoAnswer) {
            $QtMtArgs += '--auto-answer', ($AutoAnswer -join ',')
        }

        if ($PSCmdlet.ShouldProcess('Qt components', 'Update')) {
            Write-Verbose -Message 'Updating Qt components: MaintenanceTool update'
            & $QtMtPath @QtMtArgs | Where-Object {
                # HACK: Suppress useless output from what is presumably a bug
                # in the code responsible for calculating the update progress.
                $_ -notmatch 'The fraction is outside from possible value'
            }
        }
    }
}

#endregion

#region Ruby

# Clear gem cache
Function Clear-GemCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'gem' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear gem cache as gem command not found.'
        return
    }

    [String[]]$GetArgs = 'env'
    [String[]]$ClearArgs = 'sources', '--clear-all', '--silent'

    Write-Verbose -Message ('Determining gem cache path: gem {0}' -f ($GetArgs -join ' '))
    $GemEnv = & gem @GetArgs
    $GemSpecCache = $null

    foreach ($Line in $GemEnv) {
        if ($Line -match 'SPEC CACHE DIRECTORY: (.*)') {
            $GemSpecCache = $Matches[1]
            break
        }
    }

    if (!$GemSpecCache) {
        throw 'Unable to determine gem spec cache directory.'
    }

    if ($PSCmdlet.ShouldProcess($GemSpecCache, 'Clear')) {
        Write-Verbose -Message ('Clearing gem cache: gem {0}' -f ($ClearArgs -join ' '))
        & gem @ClearArgs
    }
}

# Configure environment for Ruby development
Function Switch-Ruby {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
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
            Set-EnvironmentVariable -Name 'RUBYOPT' -Value $Options
        }
    }
}

# Update Ruby gems
Function Update-RubyGems {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Test-IsWindows)) {
        Write-Warning -Message 'Updating Ruby gems is currently only supported on Windows.'
        return
    }

    if (!(Get-Command -Name 'gem' -ErrorAction Ignore)) {
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
    $Packages = [Collections.Generic.List[String]]::new()
    $PackageRegex = [Regex]::new('\(default: \S+\)')
    & gem @ListArgs | ForEach-Object {
        if (!$PackageRegex.Match($_).Success) {
            $Packages.Add($_.Split(' ')[0])
        }
    }

    Write-Verbose -Message ('Updating Ruby gems: gem {0} {1}' -f ($UpdateArgs -join ' '), ($Packages -join ' '))
    & gem @UpdateArgs @Packages

    Write-Verbose -Message ('Uninstalling obsolete Ruby gems: gem {0}' -f ($CleanupArgs -join ' '))
    & gem @CleanupArgs
}

#endregion

#region Rust

# Update Rust toolchains
Function Update-RustToolchains {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'rustup' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Rust toolchains as rustup command not found.'
        return
    }

    if ($PSCmdlet.ShouldProcess('Rust toolchains', 'Update')) {
        Write-Verbose -Message 'Updating Rust toolchains: rustup update'
        & rustup update
    }
}

#endregion

Complete-DotFilesSection
