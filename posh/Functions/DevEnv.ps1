$null = Start-DotFilesSection -Type 'Functions' -Name 'Dev Env'

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'DevEnv.format.ps1xml'))

#region .NET

# Clear NuGet cache
Function Clear-NuGetCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'nuget' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to clear NuGet cache as nuget command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'nuget')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Caches = @{
        'http-cache'      = $null
        'global-packages' = $null
        'temp'            = $null
        'plugins-cache'   = $null
    }

    $GetArgs = 'locals', 'all', '-list'
    $GetCmd = "nuget $($GetArgs -join ' ')"

    Write-Verbose -Message "Retrieving NuGet caches: ${GetCmd}"
    $NuGetLocals = & nuget @GetArgs
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve NuGet caches (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $GetCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    foreach ($Cache in $($Caches.Keys)) {
        $CacheRegex = "^${Cache}: (.*)"
        $CacheFound = $false

        foreach ($Line in $NuGetLocals) {
            if ($Line -match $CacheRegex) {
                $Caches[$Cache] = $Matches[1].TrimEnd('\')
                $CacheFound = $true
                break
            }
        }

        if (!$CacheFound) {
            $ErrMsg = "Failed to determine NuGet ${Cache} cache location."
            $ErrExc = [FormatException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ParserError
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NugetCacheNotFound', $ErrCat, $NuGetLocals)
            $PSCmdlet.WriteError($ErrRec)
        }
    }

    foreach ($Cache in $Caches.Keys) {
        if ([String]::IsNullOrEmpty($Caches[$Cache])) { continue }

        if ($PSCmdlet.ShouldProcess($Caches[$Cache], 'Clear')) {
            $ClearArgs = 'locals', $Cache, '-clear', '-verbosity', 'quiet'
            $ClearCmd = "nuget $($ClearArgs -join ' ')"

            Write-Verbose -Message "Clearing NuGet ${Cache} cache: ${ClearCmd}"
            & nuget @ClearArgs
            if ($LASTEXITCODE -ne 0) {
                $ErrMsg = "Failed to clear NuGet ${Cache} cache (rc: ${LASTEXITCODE})."
                $ErrExc = [Exception]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ClearCmd)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }
        }
    }
}

# Update .NET tools
#
# TODO: Add support for local tools
# TODO: Add dependency cooldown support when available
Function Update-DotNetTools {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    if (!(Get-Command -Name 'dotnet' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update .NET global tools as dotnet command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'dotnet')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $WriteProgressParams = @{ Activity = 'Updating .NET global tools' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Success      = $false
        WhatIf       = $false
        BeforeUpdate = [String[]]@()
        AfterUpdate  = [String[]]@()
        Output       = [String[]]@()
        ExitCode     = -1
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.DevEnv.UpdateDotNetTools')

    $VersionArgs = @('--version')
    $VersionCmd = "dotnet $($VersionArgs -join ' ')"

    $ListArgs = 'tool', 'list', '--global'
    $ListCmd = "dotnet $($ListArgs -join ' ')"

    $UpdateArgs = 'tool', 'update', '--global'
    $UpdateCmd = "dotnet $($UpdateArgs -join ' ')"

    try {
        # If we're running this version of `dotnet` for the first time the
        # welcome banner will display which may cause issues issues with output
        # parsing.
        if ($Env:DOTNET_NOLOGO) {
            $OriginalNoLogo = $Env:DOTNET_NOLOGO
        } else {
            $OriginalNoLogo = $null
        }

        $Env:DOTNET_NOLOGO = 'true'

        $CliVersionRaw = (& dotnet @VersionArgs 2>&1) -join ''
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to retrieve .NET version (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $VersionCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $CliVersion = $null
        if (![Version]::TryParse($CliVersionRaw, [Ref]$CliVersion)) {
            $ErrMsg = "Failed to parse .NET version: ${CliVersionRaw}"
            $ErrExc = [FormatException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ParserError
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'VersionParseFailed', $ErrCat, $CliVersionRaw)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Progress @WriteProgressParams -Status 'Retrieving global tools' -PercentComplete 1
        Write-Verbose -Message "Retrieving .NET global tools: ${ListCmd}"
        $Result.BeforeUpdate = [String[]]@(& dotnet @ListArgs 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to retrieve .NET global tools (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ListCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        if (!$PSCmdlet.ShouldProcess('.NET global tools', 'Update')) {
            $Result.Success = $true
            $Result.WhatIf = $true
            return $Result
        }

        # .NET 8.0.400 added the `--all` parameter to update all tools but it
        # was effectively broken until the 8.0.403 release.
        # https://github.com/dotnet/sdk/issues/42598
        if ($CliVersion -ge '8.0.403') {
            $UpdateArgs += '--all'
            $UpdateCmd += ' --all'
            $FailedCmd = $UpdateCmd

            Write-Progress @WriteProgressParams -Status 'Updating global tools' -PercentComplete 10
            Write-Verbose -Message "Updating .NET global tools: ${UpdateCmd}"
            $Result.Output = [String[]]@(& dotnet @UpdateArgs 2>&1)
            $Result.ExitCode = $LASTEXITCODE
        } else {
            # Fallback approach for .NET versions prior to 8.0.403 (see above).
            # Enumerate all the installed tools and update each individually.
            $Tools = [Collections.Generic.List[String]]::new()
            $Result.BeforeUpdate | ForEach-Object {
                if ($PSItem -notmatch '^(Package Id|-)' -and $PSItem -match '^(\S+)') {
                    $Tools.Add($Matches[1])
                }
            }

            if ($Tools.Count -gt 0) {
                $ToolsUpdated = 0
                $DotnetOutput = [Collections.Generic.List[String]]::new()

                foreach ($Tool in $Tools) {
                    Write-Progress @WriteProgressParams -Status "Updating global tool: ${Tool}" -PercentComplete ($ToolsUpdated / $Tools.Count * 90 + 10)
                    Write-Verbose -Message "Updating .NET ${Tool} global tool: ${UpdateCmd} ${Tool}"
                    $DotnetOutput.AddRange([String[]]@(& dotnet @UpdateArgs $Tool 2>&1))

                    # Only the first non-zero exit code is retained
                    if ($Result.ExitCode -ne 0) {
                        $Result.ExitCode = $LASTEXITCODE
                        $FailedCmd = "${UpdateCmd} ${Tool}"
                    }

                    $ToolsUpdated++
                }

                $Result.Output = [String[]]($DotnetOutput.ToArray())
            } else {
                $Result.Output = [String[]]@()
                $Result.ExitCode = 0
            }
        }

        if ($Result.ExitCode -eq 0) {
            $Result.Success = $true
        } else {
            $ErrMsg = "Failed to update .NET global tools (rc: $($Result.ExitCode))."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $FailedCmd)
            $PSCmdlet.WriteError($ErrRec)
        }

        Write-Progress @WriteProgressParams -Status 'Retrieving global tools' -PercentComplete 90
        Write-Verbose -Message "Retrieving .NET global tools: ${ListCmd}"
        $Result.AfterUpdate = [String[]]@(& dotnet @ListArgs 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to retrieve .NET global tools (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ListCmd)
            $PSCmdlet.WriteError($ErrRec)
        }
    } finally {
        if ($OriginalNoLogo) {
            $Env:DOTNET_NOLOGO = $OriginalNoLogo
        } else {
            $Env:DOTNET_NOLOGO = $null
        }
    }

    Write-Progress @WriteProgressParams -Completed
    return $Result
}

#endregion

#region Go

# Clear Go cache
Function Clear-GoCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'go' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to clear Go cache as go command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'go')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $BuildGetArgs = 'env', 'GOCACHE'
    $BuildGetCmd = "go $($BuildGetArgs -join ' ')"

    $ModuleGetArgs = 'env', 'GOMODCACHE'
    $ModuleGetCmd = "go $($ModuleGetArgs -join ' ')"

    $BuildClearArgs = 'clean', '-cache'
    $BuildClearCmd = "go $($BuildClearArgs -join ' ')"

    $ModuleClearArgs = 'clean', '-modcache'
    $ModuleClearCmd = "go $($ModuleClearArgs -join ' ')"

    Write-Verbose -Message "Retrieving Go build cache path: ${BuildGetCmd}"
    $GoBuildCache = (& go @BuildGetArgs) -join ''
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve Go build cache path (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $BuildGetCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    Write-Verbose -Message "Retrieving Go module cache path: ${ModuleGetCmd}"
    $GoModuleCache = (& go @ModuleGetArgs) -join ''
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve Go module cache path (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ModuleGetCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PSCmdlet.ShouldProcess($GoBuildCache, 'Clear')) {
        Write-Verbose -Message "Clearing Go build cache: ${BuildClearCmd}"
        & go @BuildClearArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to clear Go build cache (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $BuildClearCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }

    if ($PSCmdlet.ShouldProcess($GoModuleCache, 'Clear')) {
        Write-Verbose -Message "Clearing Go module cache: ${ModuleClearCmd}"
        & go @ModuleClearArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to clear Go module cache (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ModuleClearCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Configure environment for Go development
#
# Environment variables
# https://golang.org/cmd/go/#hdr-Environment_variables
Function Switch-Go {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "Go path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}
        $PathChanges = [Collections.Generic.List[String]]::new()

        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')

        $BinPath = Join-Path -Path $Path -ChildPath 'bin'
        $PathChanges.Add($BinPath)

        if ($Env:GOPATH) {
            foreach ($GoPath in $Env:GOPATH.Split([IO.Path]::PathSeparator)) {
                if (!(Test-IsPathFullyQualified -Path $GoPath)) {
                    $ErrMsg = "Found not fully qualified path while parsing GOPATH: ${GoPath}"
                    $ErrExc = [FormatException]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFullyQualified', $ErrCat, $GoPath)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }

                $GoPath = Join-Path -Path $GoPath -ChildPath 'bin'
                $PathChanges.Insert(1, $GoPath)
            }
        }

        foreach ($PathChange in $PathChanges) {
            $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $PathChange
            Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
            Write-Host $PathChange
        }

        if ($Disable -and $IncludeNonPathVars) {
            $Env:GOPATH = $null
            Write-Host -ForegroundColor 'Green' 'Unset GOPATH.'
        }

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                & $PathFunc @PathParams -Element $BinPath |
                Set-EnvironmentVariable -Name 'Path' -Scope 'User'

            # More than one path means we added paths from `GOPATH`
            if ($PathChanges.Count -gt 1) {
                # Add in reverse order excluding the last path (`$BinPath`)
                for ($i = $PathChanges.Count - 1; $i -gt 0; $i--) {
                    Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                        & $PathFunc @PathParams -Element $PathChanges[$i] |
                        Set-EnvironmentVariable -Name 'Path' -Scope 'User'
                }
            }

            if ($Enable -and ![String]::IsNullOrEmpty($Env:GOPATH)) {
                Set-EnvironmentVariable -Name 'GOPATH' -Value $Env:GOPATH -Scope 'User'
            } elseif ($Disable -and $IncludeNonPathVars) {
                Remove-EnvironmentVariable -Name 'GOPATH' -Scope 'User'
            }
        }
    }
}

# Update Go binaries
#
# TODO: Add dependency cooldown support when available
# TODO: Handle the case where `gup` wasn't installed by Go
Function Update-GoBinaries {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param()

    if (!(Get-Command -Name 'gup' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update Go binaries as gup command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'gup')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result = [PSCustomObject]@{
        Success  = $false
        WhatIf   = $false
        Gup      = [String[]]@()
        Binaries = [String[]]@()
        ExitCode = -1
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.DevEnv.UpdateGoBinaries')

    $CheckArgs = @('check')
    $UpdateArgs = @('update')

    $GupBinName = 'gup'
    if (Test-IsWindows) {
        $GupBinName += '.exe'
    }

    $CheckOnly = $false
    if ($PSCmdlet.ShouldProcess('gup', 'Update')) {
        $GupArgs = $UpdateArgs + $GupBinName
        $CheckMsg = ''
    } else {
        $GupArgs = $CheckArgs + $GupBinName
        $CheckOnly = $true
        $CheckMsg = ' (check)'
        $Result.WhatIf = $true
    }

    $GupCmd = "gup $($GupArgs -join ' ')"

    Write-Verbose -Message "Updating gup${CheckMsg}: ${GupCmd}"
    $Result.Gup = [String[]]@(& gup @GupArgs 2>&1)
    $Result.ExitCode = $LASTEXITCODE
    if ($Result.ExitCode -ne 0) {
        $ErrMsg = "Failed to update gup${CheckMsg} (rc: $($Result.ExitCode))."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $GupCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($CheckOnly) {
        $GupArgs = $CheckArgs
        $CheckMsg = ' (check)'
    } else {
        $GupArgs = $UpdateArgs
        $CheckMsg = ''
    }

    $GupCmd = "gup $($GupArgs -join ' ')"

    Write-Verbose -Message "Updating Go binaries${CheckMsg}: ${GupCmd}"
    $Result.Binaries = [String[]]@(& gup @GupArgs 2>&1)

    # Only the first non-zero exit code is retained
    if ($Result.ExitCode -ne 0) {
        $Result.ExitCode = $LASTEXITCODE
    }

    if ($Result.ExitCode -ne 0) {
        $ErrMsg = "Failed to update Go binaries ${CheckMsg} (rc: $($Result.ExitCode))."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $GupCmd)
        $PSCmdlet.WriteError($ErrRec)
    }

    # Only true if both `gup` runs completed successfully
    if ($Result.ExitCode -eq 0) {
        $Result.Success = $true
    }

    return $Result
}

#endregion

#region Google

# Configure environment for Google `depot_tools` usage
Function Switch-GoogleDepotTools {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "depot_tools path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}

        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
            $DepotToolsWinToolchain = 0
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')

        $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $Path
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
        Write-Host $Path

        if (Test-IsWindows) {
            if ($Enable) {
                $Env:DEPOT_TOOLS_WIN_TOOLCHAIN = $DepotToolsWinToolchain
                Write-Host -ForegroundColor 'Green' -NoNewline 'Set DEPOT_TOOLS_WIN_TOOLCHAIN to: '
                Write-Host $Env:DEPOT_TOOLS_WIN_TOOLCHAIN
            } elseif ($Disable -and $IncludeNonPathVars) {
                $Env:DEPOT_TOOLS_WIN_TOOLCHAIN = $null
                Write-Host -ForegroundColor 'Green' 'Unset DEPOT_TOOLS_WIN_TOOLCHAIN.'
            }
        }

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                & $PathFunc @PathParams -Element $Path |
                Set-EnvironmentVariable -Name 'Path' -Scope 'User'

            if (Test-IsWindows) {
                if ($Enable) {
                    Set-EnvironmentVariable -Name 'DEPOT_TOOLS_WIN_TOOLCHAIN' -Value $Env:DEPOT_TOOLS_WIN_TOOLCHAIN -Scope 'User'
                } elseif ($Disable -and $IncludeNonPathVars) {
                    Remove-EnvironmentVariable -Name 'DEPOT_TOOLS_WIN_TOOLCHAIN' -Scope 'User'
                }
            }
        }
    }
}

#endregion

#region Java

# Clear Gradle cache
Function Clear-GradleCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if ($Env:GRADLE_USER_HOME) {
        if (!(Test-IsPathFullyQualified -Path $Env:GRADLE_USER_HOME)) {
            $ErrMsg = "GRADLE_USER_HOME is not set to a fully qualified path: ${Env:GRADLE_USER_HOME}"
            $ErrExc = [FormatException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFullyQualified', $ErrCat, $Env:GRADLE_USER_HOME)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $GradleCache = Join-Path -Path $Env:GRADLE_USER_HOME -ChildPath 'caches'
    } else {
        $GradleCache = Join-Path -Path $HOME -ChildPath ('.gradle', 'caches' -join [IO.Path]::DirectorySeparatorChar)
    }

    $PathItem = Get-Item -LiteralPath $GradleCache -ErrorAction 'Ignore'
    if ($PathItem -is [IO.DirectoryInfo]) {
        if ($PSCmdlet.ShouldProcess($GradleCache, 'Clear')) {
            Remove-Item -Path "${GradleCache}\*" -Recurse -Verbose:$false
        }
    } elseif ($null -ne $PathItem) {
        $ErrMsg = "Gradle cache path is not a directory: ${GradleCache}"
        $ErrExc = [IO.IOException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotDirectory', $ErrCat, $GradleCache)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}

# Clear Maven cache
Function Clear-MavenCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if (!(Get-Command -Name 'mvn' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to clear Maven cache as mvn command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'mvn')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $GetArgs = 'help:evaluate', '-q', '-Dexpression=settings.localRepository', '-DforceStdout'
    $GetCmd = "mvn $($GetArgs -join ' ')"

    Write-Verbose -Message "Retrieving Maven cache path: ${GetCmd}"
    $MvnCache = (& mvn @GetArgs) -join ''
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve Maven cache path (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $GetCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PathItem = Get-Item -LiteralPath $MvnCache -ErrorAction 'Ignore'
    if ($PathItem -is [IO.DirectoryInfo]) {
        if ($PSCmdlet.ShouldProcess($MvnCache, 'Clear')) {
            Remove-Item -Path "$MvnCache\*" -Recurse -Verbose:$false
        }
    } elseif ($null -ne $PathItem) {
        $ErrMsg = "Maven cache path is not a directory: ${MvnCache}"
        $ErrExc = [IO.IOException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotDirectory', $ErrCat, $MvnCache)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}

# Configure environment for Java development
Function Switch-Java {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "Java path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}

        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        $BinPath = Join-Path -Path $Path -ChildPath 'bin'

        $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $BinPath
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
        Write-Host $BinPath

        if ($Enable) {
            $Env:JAVA_HOME = $Path
            Write-Host -ForegroundColor 'Green' -NoNewline 'Set JAVA_HOME to: '
            Write-Host $Env:JAVA_HOME
        } elseif ($Disable -and $IncludeNonPathVars) {
            $Env:JAVA_HOME = $null
            Write-Host -ForegroundColor 'Green' 'Unset JAVA_HOME.'
        }

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                & $PathFunc @PathParams -Element $BinPath |
                Set-EnvironmentVariable -Name 'Path' -Scope 'User'

            if ($Enable) {
                Set-EnvironmentVariable -Name 'JAVA_HOME' -Value $Env:JAVA_HOME -Scope 'User'
            } elseif ($Disable -and $IncludeNonPathVars) {
                Remove-EnvironmentVariable -Name 'JAVA_HOME' -Scope 'User'
            }
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

    if (!(Get-Command -Name 'npm' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to clear npm cache as npm command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'npm')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $GetArgs = 'config', 'get', '-g', 'cache'
    $GetCmd = "npm $($GetArgs -join ' ')"

    $ClearArgs = 'cache', 'clean', '--force', '--loglevel=error'
    $ClearCmd = "npm $($ClearArgs -join ' ')"

    Write-Verbose -Message "Retrieving npm cache path: ${GetCmd}"
    $NpmCache = (& npm @GetArgs) -join ''
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve npm cache path (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $GetCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PSCmdlet.ShouldProcess($NpmCache, 'Clear')) {
        Write-Verbose -Message "Clearing npm cache: ${ClearCmd}"
        & npm @ClearArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to clear npm cache (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ClearCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Configure environment for Node.js development
#
# Environment variables
# https://nodejs.org/api/cli.html#cli_environment_variables
Function Switch-Nodejs {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "Node.js path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}
        $PathChanges = [Collections.Generic.List[String]]::new()

        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        $PathChanges.Add($Path)

        if ($Env:NPM_CONFIG_PREFIX) {
            if (!(Test-IsPathFullyQualified -Path $Env:NPM_CONFIG_PREFIX)) {
                $ErrMsg = "NPM_CONFIG_PREFIX is not set to a fully qualified path: ${Env:NPM_CONFIG_PREFIX}"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFullyQualified', $ErrCat, $Env:NPM_CONFIG_PREFIX)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $GlobalNpmPath = $Env:NPM_CONFIG_PREFIX
        } else {
            $GlobalNpmPath = Join-Path -Path $Env:APPDATA -ChildPath 'npm'
        }

        $PathChanges.Add($GlobalNpmPath)

        foreach ($PathChange in $PathChanges) {
            $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $PathChange
            Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
            Write-Host $PathChange
        }

        if ($Disable -and $IncludeNonPathVars) {
            $Env:NPM_CONFIG_PREFIX = $null
            Write-Host -ForegroundColor 'Green' 'Unset NPM_CONFIG_PREFIX.'
        }

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                & $PathFunc @PathParams -Element $GlobalNpmPath |
                & $PathFunc @PathParams -Element $Path |
                Set-EnvironmentVariable -Name 'Path' -Scope 'User'

            if ($Enable -and ![String]::IsNullOrEmpty($Env:NPM_CONFIG_PREFIX)) {
                Set-EnvironmentVariable -Name 'NPM_CONFIG_PREFIX' -Value $Env:NPM_CONFIG_PREFIX -Scope 'User'
            } elseif ($Disable -and $IncludeNonPathVars) {
                Remove-EnvironmentVariable -Name 'NPM_CONFIG_PREFIX' -Scope 'User'
            }
        }
    }
}

# Update Node.js packages
#
# TODO: Add dependency cooldown support
# https://docs.npmjs.com/cli/v11/using-npm/config#min-release-age
Function Update-NodejsPackages {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'npm' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update Node.js packages as npm command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'npm')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $UpdateArgs = 'update', '--global'
    $UpdateCmd = "npm $($UpdateArgs -join ' ')"

    $UpdateNpmArgs = $UpdateArgs + 'npm'
    $UpdateNpmCmd = "${UpdateCmd} npm"

    if ($PSCmdlet.ShouldProcess('npm', 'Update')) {
        Write-Verbose -Message "Updating npm: ${UpdateNpmCmd}"
        & npm @UpdateNpmArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to update npm (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateNpmCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }

    if ($PSCmdlet.ShouldProcess('Node.js packages', 'Update')) {
        Write-Verbose -Message "Updating Node.js packages: ${UpdateCmd}"
        & npm @UpdateArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to update Node.js packages (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

#endregion

#region Perl

# Configure environment for Perl development
#
# Environment variables
# https://perldoc.perl.org/perlrun.html#ENVIRONMENT
Function Switch-Perl {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "Perl path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}
        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $PathChanges = [Collections.Generic.List[String]]::new()
        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')

        $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
        $PathChanges.Add($RootBinPath)

        $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
        $PathChanges.Insert(0, $SiteBinPath)

        $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'
        $PathChanges.Insert(0, $PerlBinPath)

        if ($Env:PERL5LIB) {
            if (!(Test-IsPathFullyQualified -Path $Env:PERL5LIB)) {
                $ErrMsg = "PERL5LIB is not set to a fully qualified path: ${Env:PERL5LIB}"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFullyQualified', $ErrCat, $Env:PERL5LIB)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $UserBasePathElements = $Env:PERL5LIB.Split([IO.Path]::DirectorySeparatorChar)
            if ($UserBasePathElements.Count -lt 3) {
                $ErrMsg = "PERL5LIB has less than expected minimum of 3 path components: ${Env:PERL5LIB}"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'InvalidPath', $ErrCat, $Env:PERL5LIB)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $UserBasePath = $UserBasePathElements[0..($UserBasePathElements.Count - 3)] -join [IO.Path]::DirectorySeparatorChar
            $UserBasePathEsc = $UserBasePath
            if ([IO.Path]::DirectorySeparatorChar -eq '\') {
                $UserBasePathEsc = $UserBasePath.Replace('\', '\\')
            }

            $UserBinPath = Join-Path -Path $UserBasePath -ChildPath 'bin'
            $PathChanges.Insert(0, $UserBinPath)
        }

        foreach ($PathChange in $PathChanges) {
            $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $PathChange
            Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
            Write-Host $PathChange
        }

        if ($Enable -and $Env:PERL5LIB) {
            # Extra options for `Module::Build`
            $Env:PERL_MB_OPT = "--install_base '${UserBasePathEsc}'"
            Write-Host -ForegroundColor 'Green' -NoNewline 'Set PERL_MB_OPT to: '
            Write-Host $Env:PERL_MB_OPT

            # Extra options for `ExtUtils::MakeMaker`
            $Env:PERL_MM_OPT = "INSTALL_BASE=`"${UserBasePathEsc}`""
            Write-Host -ForegroundColor 'Green' -NoNewline 'Set PERL_MM_OPT to: '
            Write-Host $Env:PERL_MM_OPT
        } elseif ($Disable -and $IncludeNonPathVars) {
            $Env:PERL_MB_OPT = ''
            Write-Host -ForegroundColor 'Green' 'Unset PERL_MB_OPT.'

            $Env:PERL_MM_OPT = ''
            Write-Host -ForegroundColor 'Green' 'Unset PERL_MM_OPT.'
        }

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            if ($Env:PERL5LIB) {
                Get-EnvironmentVariable -Name 'Path' |
                    & $PathFunc @PathParams -Element $UserBinPath |
                    Set-EnvironmentVariable -Name 'Path'
            }

            Get-EnvironmentVariable -Name 'Path' |
                & $PathFunc @PathParams -Element $RootBinPath |
                & $PathFunc @PathParams -Element $SiteBinPath |
                & $PathFunc @PathParams -Element $PerlBinPath |
                Set-EnvironmentVariable -Name 'Path'

            if ($Enable -and ![String]::IsNullOrEmpty($Env:PERL5LIB)) {
                Set-EnvironmentVariable -Name 'PERL_MB_OPT' -Value $Env:PERL_MB_OPT
                Set-EnvironmentVariable -Name 'PERL_MM_OPT' -Value $Env:PERL_MM_OPT
            } elseif ($Disable -and $IncludeNonPathVars) {
                Set-EnvironmentVariable -Name 'PERL_MB_OPT' -Value ''
                Set-EnvironmentVariable -Name 'PERL_MM_OPT' -Value ''
            }
        }
    }
}

#endregion

#region PHP

# Configure environment for PHP development
Function Switch-PHP {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "PHP path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}

        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')

        $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $Path
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
        Write-Host $Path

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                & $PathFunc @PathParams -Element $Path |
                Set-EnvironmentVariable -Name 'Path' -Scope 'User'
        }
    }
}

#endregion

#region Python

# Clear pip cache
Function Clear-PipCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'python' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to clear pip cache as python command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'python')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PipModuleArgs = '-m', 'pip'
    $PipModuleCmd = "python $($PipModuleArgs -join ' ')"

    $VersionArgs = $PipModuleArgs + '--version'
    $VersionCmd = "python $($VersionArgs -join ' ')"

    $GetArgs = $PipModuleArgs + 'cache', 'info'
    $GetCmd = "python $($GetArgs -join ' ')"

    $ClearArgs = $PipModuleArgs + 'cache', 'purge', '-qqq'
    $ClearCmd = "python $($ClearArgs -join ' ')"

    $null = & python @PipModuleArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = 'Unable to clear pip cache as pip module not found.'
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PipModuleCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PipVersionRaw = (& python @VersionArgs 2>&1) -join ''
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve pip version (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $VersionCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PipVersionRaw -notmatch '^pip ([0-9]+\.[0-9]+(\.[0-9]+)?)') {
        $ErrMsg = "Failed to extract pip version: ${PipVersionRaw}"
        $ErrExc = [FormatException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ParserError
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $PipVersionRaw)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PipVersion = [Version]$Matches[1]
    $PipSupportsCacheIndexV2 = $PipVersion -ge '23.3'

    Write-Verbose -Message "Retrieving pip cache path: ${GetCmd}"
    $PipCacheInfo = & python @GetArgs
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve pip cache path (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $GetCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

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
        } else { continue }

        $PipCachePaths.Add($Matches[1])
        if ($PipCacheIndex -and $PipCacheWheels -and $PipCacheIndexV2) { break }
    }

    if (!$PipCacheIndexV2) {
        $ErrMsg = 'Failed to determine pip package index page cache v2 location.'
        $ErrExc = [FormatException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ParserError
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PipCacheNotFound', $ErrCat, $PipCacheInfo)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (!$PipCacheIndex) {
        $ErrMsg = 'Failed to determine pip package index page cache location.'
        $ErrExc = [FormatException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ParserError
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PipCacheNotFound', $ErrCat, $PipCacheInfo)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (!$PipCacheWheels) {
        $ErrMsg = 'Failed to determine pip wheels cache location.'
        $ErrExc = [FormatException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ParserError
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PipCacheNotFound', $ErrCat, $PipCacheInfo)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PSCmdlet.ShouldProcess($PipCachePaths -join ', ', 'Clear')) {
        Write-Verbose -Message "Clearing pip cache: ${ClearCmd}"
        & python @ClearArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to clear pip cache (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ClearCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Configure environment for Python development
#
# Environment variables
# https://docs.python.org/3/using/cmdline.html#environment-variables
Function Switch-Python {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [ValidatePattern('[0-9]+\.[0-9]+')]
        [String]$Version,

        [Parameter(ParameterSetName = 'Enable')]
        [ValidateSet('Dev', 'UTF-8')]
        [String[]]$Features = @('UTF-8'),

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        if (!$Version) {
            if (!(Get-Command -Name 'python' -ErrorAction 'Ignore')) {
                $ErrMsg = 'Unable to detect Python version as python command not found.'
                $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'python')
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }
        }

        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "Python path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}
        $PathChanges = [Collections.Generic.List[String]]::new()
        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        $PathChanges.Add($Path)

        $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
        $PathChanges.Add($ScriptsPath)

        if ($Env:PYTHONUSERBASE) {
            if (!(Test-IsPathFullyQualified -Path $Env:PYTHONUSERBASE)) {
                $ErrMsg = "PYTHONUSERBASE is not set to a fully qualified path: ${Env:PYTHONUSERBASE}"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFullyQualified', $ErrCat, $Env:PYTHONUSERBASE)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Verbose -Message "Using explicit PYTHONUSERBASE: ${Env:PYTHONUSERBASE}"
            $PythonUserBase = $Env:PYTHONUSERBASE
        } else {
            Write-Verbose -Message "Using default PYTHONUSERBASE: ${Env:APPDATA}"
            $PythonUserBase = $Env:APPDATA
        }

        $LocalScriptsSharedPath = Join-Path -Path $PythonUserBase -ChildPath 'Python\Scripts'
        $PathChanges.Add($LocalScriptsSharedPath)

        if (!$Version) {
            $PythonExe = Join-Path -Path $Path -ChildPath 'python.exe'

            try {
                $PythonFailed = $false
                $PythonVersionRaw = & @PythonExe -V 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $PythonFailed = $true
                    $ErrMsg = "Failed to retrieve Python version (rc: ${LASTEXITCODE})."
                }
            } catch {
                $PythonFailed = $true
                $ErrMsg = "Python executable missing or could not be executed: ${PythonExe}"
            } finally {
                if ($PythonFailed) {
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PythonExe)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }

            if ($PythonVersionRaw -notmatch '[0-9]+\.[0-9]+') {
                $ErrMsg = "Failed to retrieve Python version: ${PythonVersionRaw}"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $PythonVersionRaw)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $Version = $Matches[0]
        }

        $NativeVersion = [Version]$Version
        $StrippedVersion = $Version -replace '\.'

        $LocalScriptsVersionedPath = Join-Path -Path $PythonUserBase -ChildPath "Python\Python${StrippedVersion}\Scripts"
        $PathChanges.Add($LocalScriptsVersionedPath)

        foreach ($PathChange in $PathChanges) {
            $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $PathChange
            Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
            Write-Host $PathChange
        }

        # Python Development Mode
        $DevMode = $false
        if ($Features -contains 'Dev') {
            if ($Enable) {
                if ($NativeVersion -ge '3.7') {
                    $DevMode = $true
                } else {
                    Write-Warning -Message 'Not enabling development mode as Python release is not >= 3.7.'
                }
            }

            if ($DevMode) {
                $Env:PYTHONDEVMODE = 1
                Write-Host -ForegroundColor 'Green' -NoNewline 'Set PYTHONDEVMODE to: '
                Write-Host $Env:PYTHONDEVMODE
            } else {
                $Env:PYTHONDEVMODE = ''
                Write-Host -ForegroundColor 'Green' 'Unset PYTHONDEVMODE.'
            }
        }

        # UTF-8 Mode (see PEP 540)
        $Utf8Mode = $false
        if ($Features -contains 'UTF-8') {
            if ($Enable) {
                if ($NativeVersion -ge '3.7') {
                    $Utf8Mode = $true
                } else {
                    Write-Warning -Message 'Not enabling UTF-8 mode as Python release is not >= 3.7.'
                }
            }

            if ($Utf8Mode) {
                $Env:PYTHONUTF8 = 1
                Write-Host -ForegroundColor 'Green' -NoNewline 'Set PYTHONUTF8 to: '
                Write-Host $Env:PYTHONUTF8
            } else {
                $Env:PYTHONUTF8 = ''
                Write-Host -ForegroundColor 'Green' 'Unset PYTHONUTF8.'
            }
        }

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            Get-EnvironmentVariable -Name 'Path' |
                & $PathFunc @PathParams -Element $LocalScriptsVersionedPath |
                & $PathFunc @PathParams -Element $LocalScriptsSharedPath |
                & $PathFunc @PathParams -Element $ScriptsPath |
                & $PathFunc @PathParams -Element $Path |
                Set-EnvironmentVariable -Name 'Path'

            if ($DevMode) {
                Set-EnvironmentVariable -Name 'PYTHONDEVMODE' -Value $Env:PYTHONDEVMODE
            }

            if ($Utf8Mode) {
                Set-EnvironmentVariable -Name 'PYTHONUTF8' -Value $Env:PYTHONUTF8
            }

            if ($Disable -and $IncludeNonPathVars) {
                Set-EnvironmentVariable -Name 'PYTHONDEVMODE' -Value ''
                Set-EnvironmentVariable -Name 'PYTHONUTF8' -Value ''
            }
        }
    }
}

# Update Python pip packages
#
# TODO: Add dependency cooldown support
# https://pip.pypa.io/en/stable/cli/pip_install/#cmdoption-uploaded-prior-to
Function Update-PythonPipPackages {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if ([String]::IsNullOrWhiteSpace($Env:VIRTUAL_ENV) -and (Test-IsUnix)) {
        $ErrMsg = 'Updating pip packages outside of a virtualenv is only supported on Windows.'
        $ErrExc = [NotSupportedException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'OSNotSupported', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (!(Get-Command -Name 'python' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update pip packages as python command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'python')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PipModuleArgs = '-m', 'pip'
    $PipModuleCmd = "python $($PipModuleArgs -join ' ')"

    $PipdeptreeModuleArgs = '-m', 'pipdeptree'
    $PipdeptreeModuleCmd = "python $($PipdeptreeModuleArgs -join ' ')"

    $PipVersionArgs = $PipModuleArgs + '--version'
    $PipVersionCmd = "python $($PipVersionArgs -join ' ')"

    $PipUpdateBaseArgs = $PipModuleArgs + @('install', '--upgrade')

    $null = & python @PipModuleArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = 'Unable to update pip packages as pip module not found.'
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PipModuleCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PipdeptreeOutput = & python @PipdeptreeModuleArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = 'Unable to update pip packages as pipdeptree module not found.'
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PipdeptreeModuleCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PipVersionRaw = (& python @PipVersionArgs 2>&1) -join ''
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve pip version (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PipVersionCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PipVersionRaw -notmatch '^pip ([0-9]+\.[0-9]+(\.[0-9]+)?)') {
        $ErrMsg = "Failed to extract pip version: ${PipVersionRaw}"
        $ErrExc = [FormatException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ParserError
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $PipVersionRaw)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PipVersion = [Version]$Matches[1]

    if ($PipVersion -ge '10.0') {
        $PipUpdateBaseArgs += '--no-warn-script-location'
    }

    if ($PipVersion -lt '25.0') {
        $PipUpdateBaseArgs = @('--no-python-version-warning') + $PipUpdateBaseArgs
    }

    if ($PSCmdlet.ShouldProcess('pip package', 'Update')) {
        $PipUpdatePipArgs = $PipUpdateBaseArgs + 'pip'
        $PipUpdatePipCmd = "python $($PipUpdatePipArgs -join ' ')"

        Write-Verbose -Message "Updating pip package: ${PipUpdatePipCmd}"
        & python @PipUpdatePipArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to update pip (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PipUpdatePipCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }

    Write-Verbose -Message 'Enumerating pip packages ...'
    $Packages = [Collections.Generic.List[String]]::new()
    $PackageRegex = [Regex]::new('^(\S+)==')
    $PipdeptreeOutput | ForEach-Object {
        $Package = $PackageRegex.Match($PSItem)
        if ($Package.Success) {
            $Packages.Add($Package.Groups[1].Value)
        }
    }

    if ($PSCmdlet.ShouldProcess('pip packages', 'Update')) {
        $PipUpdateArgs = $PipUpdateBaseArgs + @('--upgrade-strategy', 'eager')
        $PipUpdateCmd = "python $($PipUpdateArgs -join ' ')"

        Write-Verbose -Message "Updating pip packages: ${PipUpdateCmd} $($Packages -join ' ')"
        & python @PipUpdateArgs @Packages
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to update pip packages (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PipUpdateCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Update Python pipx packages
#
# TODO: Add dependency cooldown support when available
Function Update-PythonPipxPackages {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'python' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update pipx packages as python command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'python')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $PipxModuleArgs = '-m', 'pipx'

    $ListArgs = $PipxModuleArgs + 'list'
    $ListCmd = "python $($ListArgs -join ' ')"

    $UpdateArgs = $PipxModuleArgs + 'upgrade-all'
    $UpdateCmd = "python $($UpdateArgs -join ' ')"

    # Use `list` as invoking without a command will return a non-zero exit code
    $null = & python @ListArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = 'Unable to update pipx packages as pipx module not found.'
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ListCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PSCmdlet.ShouldProcess('pipx packages', 'Update')) {
        try {
            # Outputting emojis can be problematic on Windows. This isn't as
            # big an issue as it used to be but there's still some edge cases.
            # In particular, Python will default to MBCS encoding on Windows
            # when `sys.stdin` and/or `sys.output` is redirected to a pipe.
            #
            # Enabling Python's UTF-8 mode will resolve this issue, but it's
            # non-default and only available since Python 3.7, so just disable
            # emojis outright as the reliable workaround.
            if ($Env:USE_EMOJI) {
                $OriginalUseEmoji = $Env:USE_EMOJI
            } else {
                $OriginalUseEmoji = $null
            }

            $Env:USE_EMOJI = 0

            Write-Verbose -Message "Updating pipx packages: ${UpdateCmd}"
            & python @UpdateArgs
            if ($LASTEXITCODE -ne 0) {
                $ErrMsg = "Failed to update pipx packages (rc: ${LASTEXITCODE})."
                $ErrExc = [Exception]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateCmd)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }
        } finally {
            if ($OriginalUseEmoji) {
                $Env:USE_EMOJI = $OriginalUseEmoji
            } else {
                $Env:USE_EMOJI = $null
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
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        $PathAttrCollection = [Collections.ObjectModel.Collection[Attribute]]::new()
        $PathParamAttr = [Management.Automation.ParameterAttribute]::new()
        $PathAttrCollection.Add($PathParamAttr)

        if (Test-IsWindows) {
            $ValidateNotNullOrEmptyAttr = [Management.Automation.ValidateNotNullOrEmptyAttribute]::new()
            $PathAttrCollection.Add($ValidateNotNullOrEmptyAttr)
        } else {
            $PathParamAttr.Mandatory = $true
        }

        $PathParam = [Management.Automation.RuntimeDefinedParameter]::new('Path', [String], $PathAttrCollection)
        $RuntimeParams.Add('Path', $PathParam)

        return $RuntimeParams
    }

    Begin {
        if (!$PSBoundParameters.ContainsKey('Path') -and (Test-IsWindows)) {
            $PSBoundParameters['Path'] = "${Env:HOMEDRIVE}\DevEnvs\Qt\MaintenanceTool.exe"
        }
    }

    End {
        $QtMtName = 'MaintenanceTool'
        if (Test-IsWindows) {
            $QtMtName += '.exe'
        }

        $QtMtPath = Get-Item -LiteralPath $PSBoundParameters['Path'] -ErrorAction 'Ignore'
        if ($QtMtPath -is [IO.DirectoryInfo]) {
            $QtMtPath = Join-Path -Path $QtMtPath.FullName -ChildPath $QtMtName
            $QtMtPath = Get-Item -LiteralPath $QtMtPath -ErrorAction 'Ignore'
        }

        if ($QtMtPath -isnot [IO.FileInfo] -or $QtMtPath.Name -ne $QtMtName) {
            $ErrMsg = 'Unable to update Qt components as MaintenanceTool command was not found.'
            $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'MaintenanceTool')
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        if (!$PSCmdlet.ShouldProcess('Qt components', 'Update')) { return }

        $QtMtArgs = 'update', '--accept-licenses', '--confirm-command'

        if ($AutoAnswer) {
            $QtMtArgs += '--auto-answer', ($AutoAnswer -join ',')
        }

        $QtMtCmd = "MaintenanceTool $($QtMtArgs -join ' ')"

        Write-Verbose -Message "Updating Qt components: ${QtMtCmd}"
        & $QtMtPath @QtMtArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to update Qt components (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $QtMtCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
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

    if (!(Get-Command -Name 'gem' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to clear gem cache as gem command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'gem')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $GetArgs = @('env')
    $GetCmd = "gem $($GetArgs -join ' ')"

    $ClearArgs = 'sources', '--clear-all', '--silent'
    $ClearCmd = "gem $($ClearArgs -join ' ')"

    Write-Verbose -Message "Retrieving gem environment: ${GetCmd}"
    $GemEnv = & gem @GetArgs
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve Gem environment (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $GetCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $GemSpecCache = $null
    foreach ($Line in $GemEnv) {
        if ($Line -match 'SPEC CACHE DIRECTORY: (.+)') {
            $GemSpecCache = $Matches[1]
            break
        }
    }

    if (!$GemSpecCache) {
        $ErrMsg = "Failed to determine gem cache path (rc: ${LASTEXITCODE})."
        $ErrExc = [FormatException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ParserError
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $GemEnv)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PSCmdlet.ShouldProcess($GemSpecCache, 'Clear')) {
        Write-Verbose -Message "Clearing gem cache: ${ClearCmd}"
        & gem @ClearArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to clear gem cache (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ClearCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Configure environment for Ruby development
#
# Environment variables
# https://docs.ruby-lang.org/en/master/language/options_md.html
Function Switch-Ruby {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Enable')]
        [String]$Options = '-Eutf-8',

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "Ruby path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}

        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
            $Options = $Options.Trim()
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        $BinPath = Join-Path -Path $Path -ChildPath 'bin'

        $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $BinPath
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
        Write-Host $BinPath

        if ($Enable -and $Options) {
            $SetOptions = $true

            if ($Env:RUBYOPT -and $Env:RUBYOPT -ne $Options) {
                if ($Force) {
                    Write-Warning -Message "Overwriting existing RUBYOPT which has the following value: ${Env:RUBYOPT}"
                } else {
                    Write-Warning -Message "Skipping setting RUBYOPT as it already exists with a different value: ${Env:RUBYOPT}"
                    $SetOptions = $false
                }
            }

            if ($SetOptions) {
                $Env:RUBYOPT = $Options
                Write-Host -ForegroundColor 'Green' -NoNewline 'Set RUBYOPT to: '
                Write-Host $Env:RUBYOPT
            }
        } elseif ($Disable -and $IncludeNonPathVars) {
            $Env:RUBYOPT = $null
            Write-Host -ForegroundColor 'Green' 'Unset RUBYOPT.'
        }

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                & $PathFunc @PathParams -Element $BinPath |
                Set-EnvironmentVariable -Name 'Path' -Scope 'User'

            if ($Enable -and ![String]::IsNullOrEmpty($Env:RUBYOPT)) {
                Set-EnvironmentVariable -Name 'RUBYOPT' -Value $Env:RUBYOPT -Scope 'User'
            } elseif ($Disable -and $IncludeNonPathVars) {
                Remove-EnvironmentVariable -Name 'RUBYOPT' -Scope 'User'
            }
        }
    }
}

# Update Ruby gems
#
# TODO: Add dependency cooldown support when available
# https://github.com/ruby/rubygems/discussions/9113
Function Update-RubyGems {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([String[]])]
    Param()

    if (!(Test-IsWindows)) {
        $ErrMsg = 'Updating Ruby gems is only supported on Windows.'
        $ErrExc = [NotSupportedException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'OSNotSupported', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (!(Get-Command -Name 'gem' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update Ruby gems as gem command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'gem')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $ListArgs = 'list', '--local', '--no-details'
    $ListCmd = "gem $($ListArgs -join ' ')"

    $UpdateArgs = 'update', '--no-document'
    $UpdateCmd = "gem $($UpdateArgs -join ' ')"

    $UpdateSystemArgs = $UpdateArgs + '--system'
    $UpdateSystemCmd = "gem $($UpdateSystemArgs -join ' ')"

    $CleanupArgs = @('cleanup')
    $CleanupCmd = "gem $($CleanupArgs -join ' ')"

    $ExplainMsg = ''
    if (!$PSCmdlet.ShouldProcess('RubyGems system', 'Update')) {
        $ExplainMsg += ' (explain only)'
        $UpdateSystemArgs += '--explain'
        $UpdateSystemCmd += ' --explain'
    }

    Write-Verbose -Message "Updating RubyGems system${ExplainMsg}: ${UpdateSystemCmd}"
    & gem @UpdateSystemArgs
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to update RubyGems system${ExplainMsg} (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateSystemCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    Write-Verbose -Message "Retrieving Ruby gems: ${ListCmd}"
    $Packages = [Collections.Generic.List[String]]::new()
    $PackageRegex = [Regex]::new('\(default: \S+\)')
    & gem @ListArgs | ForEach-Object {
        if (!$PackageRegex.Match($PSItem).Success) {
            $Packages.Add($PSItem.Split(' ')[0])
        }
    }

    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve Ruby gems (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ListCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $ExplainMsg = ''
    if (!$PSCmdlet.ShouldProcess('Ruby gems', 'Update')) {
        $ExplainMsg += ' (explain only)'
        $UpdateArgs += '--explain'
        $UpdateCmd += ' --explain'
    }

    Write-Verbose -Message "Updating Ruby gems${ExplainMsg}: ${UpdateCmd} $($Packages -join ' ')"
    & gem @UpdateArgs @Packages
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to update Ruby gems${ExplainMsg} (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "${UpdateCmd} $($Packages -join ' ')")
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $DryrunMsg = ''
    if (!$PSCmdlet.ShouldProcess('Obsolete Ruby gems', 'Uninstall')) {
        $DryrunMsg = ' (dry-run)'
        $CleanupArgs += '--dry-run'
        $CleanupCmd += ' --dry-run'
    }

    Write-Verbose -Message "Uninstalling obsolete Ruby gems${DryrunMsg}: ${CleanupCmd}"
    & gem @CleanupArgs
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to uninstall obsolete Ruby gems${DryrunMsg} (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $CleanupCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}

#endregion

#region Rust

# Configure environment for Rust development
Function Switch-Rust {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Force
    )

    DynamicParam {
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if (Test-IsWindows) {
            $PersistParamAttr = [Management.Automation.ParameterAttribute]@{}
            $PersistParam = [Management.Automation.RuntimeDefinedParameter]::new('Persist', [Switch], $PersistParamAttr)
            $RuntimeParams.Add('Persist', $PersistParam)
        }

        return $RuntimeParams
    }

    End {
        if (!$Path) {
            if ($Env:CARGO_HOME) {
                $Path = $Env:CARGO_HOME
                Write-Verbose -Message "Using CARGO_HOME path: ${Path}"
            } else {
                $Path = Join-Path -Path $HOME -ChildPath '.cargo'
                Write-Verbose -Message "Using default Cargo path: ${Path}"
            }
        }

        $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($PathItem -isnot [IO.DirectoryInfo]) {
            $ErrMsg = "Cargo path is inaccessible or not a directory: ${Path}"

            if (!$Force) {
                if ($PSBoundParameters.ContainsKey('Path')) {
                    $ErrExc = [ArgumentException]::new($ErrMsg)
                    $ErrId = 'PSInvalidArgument'
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                } else {
                    $ErrExc = [IO.IOException]::new($ErrMsg)
                    $ErrId = 'PathNotDirectory'
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                }

                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, $ErrId, $ErrCat, $Path)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $ErrMsg
        }

        $Enable = !$Disable
        $PathParams = @{}

        if ($Enable) {
            $PathFunc = 'Add-PathStringElement'
            $PathParams['Action'] = 'Prepend'
            $PathChangesDesc = 'Prepended to PATH: '
        } else {
            $PathFunc = 'Remove-PathStringElement'
            $PathChangesDesc = 'Removed from PATH: '
        }

        $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        $BinPath = Join-Path -Path $Path -ChildPath 'bin'

        $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $BinPath
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
        Write-Host $BinPath

        if ($Disable -and $IncludeNonPathVars) {
            $Env:CARGO_HOME = $null
            Write-Host -ForegroundColor 'Green' 'Unset CARGO_HOME.'
        }

        if ($PSBoundParameters['Persist']) {
            Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
            if ($Enable) { $PathParams['Action'] = 'Append' }

            Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                & $PathFunc @PathParams -Element $BinPath |
                Set-EnvironmentVariable -Name 'Path' -Scope 'User'

            if ($Enable -and ![String]::IsNullOrEmpty($Env:CARGO_HOME)) {
                Set-EnvironmentVariable -Name 'CARGO_HOME' -Value $Path -Scope 'User'
            } elseif ($Disable -and $IncludeNonPathVars) {
                Remove-EnvironmentVariable -Name 'CARGO_HOME' -Scope 'User'
            }
        }
    }
}

# Update Rust toolchains
Function Update-RustToolchains {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([String[]])]
    Param()

    if (!(Get-Command -Name 'rustup' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update Rust toolchains as rustup command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'rustup')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PSCmdlet.ShouldProcess('Rust toolchains', 'Update')) {
        Write-Verbose -Message 'Updating Rust toolchains: rustup update'
        & rustup update
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to update Rust toolchains (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, 'rustup update')
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

#endregion

Complete-DotFilesSection
