$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Dev Env (Windows)'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'DevEnv-Win.format.ps1xml'))

#region Cygwin

# Configure environment for Cygwin usage
#
# Environment variables
# https://cygwin.com/cygwin-ug-net/setup-env.html
Function Global:Switch-Cygwin {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Enable')]
        [ValidateSet('Default', 'Lnk', 'Native', 'NativeStrict', 'Sys')]
        [String]$Symlinks = 'NativeStrict',

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Persist,
        [Switch]$Force
    )

    if (!(Test-IsPathFullyQualified -Path $Path)) {
        $Path = Join-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation -ChildPath $Path
    }

    $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
    if ($PathItem -isnot [IO.DirectoryInfo]) {
        $Msg = "Cygwin path is inaccessible or not a directory: ${Path}"

        if (!$Force) {
            $ErrExc = [ArgumentException]::new($Msg, 'Path')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Warning -Message $Msg
    }

    $Enable = !$Disable
    $PathChanges = [Collections.Generic.List[String]]::new()
    $PathParams = @{}
    $DirSepChars = [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar

    if ($Enable) {
        $PathFunc = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $PathChangesDesc = 'Prepended to PATH: '
    } else {
        $PathFunc = 'Remove-PathStringElement'
        $PathChangesDesc = 'Removed from PATH: '
    }

    $Path = [IO.Path]::GetFullPath($Path).TrimEnd($DirSepChars)

    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    $PathChanges.Add($BinPath)

    $UsrLocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'
    $PathChanges.Add($UsrLocalBinPath)

    foreach ($PathChange in $PathChanges) {
        $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $PathChange
        Write-Host -NoNewline -ForegroundColor 'Green' $PathChangesDesc
        Write-Host $PathChange
    }

    if ($Enable -and $Symlinks -ne 'Default') {
        $CygwinCfg = [Collections.Generic.List[String]]::new()

        if ($Env:CYGWIN) {
            foreach ($Setting in $Env:CYGWIN.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) {
                if ($Setting -notmatch 'winsymlinks') {
                    $CygwinCfg.Add($Setting)
                }
            }
        }

        $CygwinCfg.Add("winsymlinks:$($Symlinks.ToLower())")
        $CygwinCfg.Sort()

        $Env:CYGWIN = $CygwinCfg -join ' '
        Write-Host -NoNewline -ForegroundColor 'Green' 'Set CYGWIN to: '
        Write-Host $Env:CYGWIN
    } elseif ($Disable -and $IncludeNonPathVars) {
        $Env:CYGWIN = $null
        Write-Host -ForegroundColor 'Green' 'Unset CYGWIN.'
    }

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
            & $PathFunc @PathParams -Element $UsrLocalBinPath |
            & $PathFunc @PathParams -Element $BinPath |
            Set-EnvironmentVariable -Name 'Path' -Scope 'User'

        if ($Enable -and ![String]::IsNullOrWhiteSpace($Env:CYGWIN)) {
            Set-EnvironmentVariable -Name 'CYGWIN' -Value $Env:CYGWIN -Scope 'User'
        } elseif ($Disable -and $IncludeNonPathVars) {
            Remove-EnvironmentVariable -Name 'CYGWIN' -Scope 'User'
        }
    }
}

# Update Cygwin runtime & packages
#
# Cygwin FAQ: Is there a command-line installer?
# https://cygwin.com/faq/faq.html#faq.setup.cli
Function Global:Update-Cygwin {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$SetupFile = "${Env:HOMEDRIVE}\DevEnvs\Cygwin\setup-x86_64.exe",

        [ValidateNotNullOrEmpty()]
        [String]$InstallDir = "${Env:HOMEDRIVE}\DevEnvs\Cygwin"
    )

    if (!(Test-IsPathFullyQualified -Path $SetupFile)) {
        $SetupFile = Join-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation -ChildPath $SetupFile
    }

    $SetupFileItem = Get-Item -LiteralPath $SetupFile -ErrorAction 'Ignore'
    if ($SetupFileItem -isnot [IO.FileInfo]) {
        $ExcMsg = "Cygwin setup path is inaccessible or not a file: ${SetupFile}"
        $ErrExc = [ArgumentException]::new($ExcMsg, 'SetupFile')
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $SetupFile)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $SetupFile = [IO.Path]::GetFullPath($SetupFile)

    if (!(Test-IsPathFullyQualified -Path $InstallDir)) {
        $InstallDir = Join-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation -ChildPath $InstallDir
    }

    $InstallDirItem = Get-Item -LiteralPath $InstallDir -ErrorAction 'Ignore'
    if ($InstallDirItem -isnot [IO.DirectoryInfo]) {
        $ExcMsg = "Cygwin install path is inaccessible or not a directory: ${InstallDir}"
        $ErrExc = [IO.DirectoryNotFoundException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'DirectoryNotFound', $ErrCat, $InstallDir)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $DirSepChars = [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar
    $InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd($DirSepChars)

    # Setup performs a new installation when run against a root directory
    # without an existing installation, so verify the installed packages
    # database exists as a guard against this.
    $InstalledDbPath = Join-Path -Path $InstallDir -ChildPath 'etc\setup\installed.db'
    if (!(Test-Path -LiteralPath $InstalledDbPath -PathType 'Leaf')) {
        $ExcMsg = "Unable to update Cygwin as installed packages database not found: ${InstalledDbPath}"
        $ErrExc = [IO.FileNotFoundException]::new($ExcMsg, $InstalledDbPath)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFound', $ErrCat, $InstalledDbPath)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result = [PSCustomObject]@{
        Success  = $false
        ExitCode = -1
        WhatIf   = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.DevEnvWin.UpdateCygwin')

    if (!$PSCmdlet.ShouldProcess('Cygwin runtime & packages', 'Update')) {
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    $SetupArgs = [Collections.Generic.List[String]]::new()
    $SetupArgs.Add('--quiet-mode')
    $SetupArgs.Add(('--root "{0}"' -f $InstallDir))
    $SetupArgs.Add('--upgrade-also')
    $SetupArgs.Add('--delete-orphans') # Packages no longer in repository
    $SetupArgs.Add('--no-shortcuts')

    $SetupCmd = "${SetupFile} $($SetupArgs -join ' ')"

    try {
        Write-Verbose -Message "Updating Cygwin runtime & packages: ${SetupCmd}"
        $Setup = Start-Process -FilePath $SetupFile -ArgumentList ($SetupArgs -join ' ') -PassThru -Wait -ErrorAction 'Stop'
    } catch {
        $ExcMsg = "Failed to start Cygwin setup: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ExcMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidOperation
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $SetupCmd)
        $PSCmdlet.WriteError($ErrRec)
        return $Result
    }

    if ($Setup.ExitCode -ne 0) {
        $ExcMsg = "Cygwin setup exited with non-zero exit code: $($Result.ExitCode)"
        $ErrExc = [Exception]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $SetupCmd)
        $PSCmdlet.WriteError($ErrRec)
        return $Result
    }

    $Result.Success = $true
    return $Result
}

#endregion

#region MSYS2

# Update MSYS2 runtime & packages
Function Global:Update-MSYS2 {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "${Env:HOMEDRIVE}\DevEnvs\MSYS2"
    )

    Function Get-MSYS2Version {
        [CmdletBinding()]
        [OutputType([String])]
        Param(
            [Parameter(Mandatory)]
            [String]$Bash,

            [Switch]$Fatal
        )

        $VersionArgs = '-Q', 'msys2-runtime'
        $VersionCmd = "pacman $($VersionArgs -join ' ')"

        Write-Verbose -Message "Retrieving MSYS2 runtime version: ${VersionCmd}"
        $Result = Invoke-Pacman -Bash $Bash -Arguments $VersionArgs

        if ($Result.ExitCode -ne 0) {
            $ExcMsg = "pacman exited with non-zero exit code querying MSYS2 runtime version: $($Result.ExitCode)"
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $VersionCmd)

            if ($Fatal) {
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $PSCmdlet.WriteError($ErrRec)
            return '(unknown)'
        }

        $ResultOutput = $Result.Output -join ' '
        if ($ResultOutput -notmatch '\bmsys2-runtime\s+(\S+)\b') {
            $Msg = "Failed to extract MSYS2 runtime version: ${ResultOutput}"

            if ($Fatal) {
                $ErrExc = [FormatException]::new($Msg)
                $ErrCat = [Management.Automation.ErrorCategory]::ParserError
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $ResultOutput)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Warning -Message $Msg
            return '(unknown)'
        }

        return $Matches[1]
    }

    Function Invoke-Pacman {
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        Param(
            [Parameter(Mandatory)]
            [String]$Bash,

            [Parameter(Mandatory)]
            [String[]]$Arguments
        )

        $Result = [PSCustomObject]@{
            Output   = [String[]]@()
            ExitCode = -1
        }

        $Command = "pacman $($Arguments -join ' ')"

        $OriginalMsystemEnv = $Env:MSYSTEM
        $OriginalOutputEncoding = [Console]::OutputEncoding

        # Workaround for engine behaviour on PowerShell releases prior to 7.2.
        # On earlier releases, `$ErrorActionPreference` applies to redirected
        # `stderr` output from native commands, resulting in termination if set
        # to `Stop`.
        $OriginalErrorActionPreference = $ErrorActionPreference

        try {
            $ErrorActionPreference = 'Continue'
            [Console]::OutputEncoding = [Text.Encoding]::UTF8

            # Set the login shell for the MSYS2 environment
            $Env:MSYSTEM = 'MSYS'

            $Result.Output = [String[]]@(& $Bash -l -c $Command 2>&1)
            $Result.ExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $OriginalErrorActionPreference
            [Console]::OutputEncoding = $OriginalOutputEncoding

            if ($OriginalMsystemEnv) {
                $Env:MSYSTEM = $OriginalMsystemEnv
            } else {
                $Env:MSYSTEM = $null
            }
        }

        return $Result
    }

    if (!(Test-IsPathFullyQualified -Path $Path)) {
        $Path = Join-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation -ChildPath $Path
    }

    $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
    if ($PathItem -isnot [IO.DirectoryInfo]) {
        $ExcMsg = "MSYS2 path is inaccessible or not a directory: ${Path}"
        $ErrExc = [ArgumentException]::new($ExcMsg, 'Path')
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $DirSepChars = [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar
    $Path = [IO.Path]::GetFullPath($Path).TrimEnd($DirSepChars)

    $BashPath = Join-Path -Path $Path -ChildPath 'usr\bin\bash.exe'
    $PacmanPath = Join-Path -Path $Path -ChildPath 'usr\bin\pacman.exe'

    foreach ($BinaryPath in $BashPath, $PacmanPath) {
        if (Test-Path -LiteralPath $BinaryPath -PathType 'Leaf') { continue }

        $BinaryName = [IO.Path]::GetFileName($BinaryPath)
        $ExcMsg = "Unable to update MSYS2 as ${BinaryName} command not found: ${Path}"
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ExcMsg)
        $ErrExc.CommandName = $BinaryName
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, $BinaryName)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result = [PSCustomObject]@{
        Success      = $false
        BeforeUpdate = ''
        AfterUpdate  = ''
        CoreUpgrade  = $false
        Refresh      = [String[]]@()
        Upgrade      = [String[]]@()
        ExitCode     = -1
        WhatIf       = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.DevEnvWin.UpdateMSYS2')

    $RefreshArgs = '-Sy', '--noprogressbar'
    $RefreshCmd = "pacman $($RefreshArgs -join ' ')"

    $UpgradeArgs = '-Su', '--noconfirm', '--noprogressbar'
    $UpgradeCmd = "pacman $($UpgradeArgs -join ' ')"

    $UpgradeReportOnlyArgs = @('-Qu')
    $UpgradeReportOnlyCmd = "pacman $($UpgradeReportOnlyArgs -join ' ')"

    $Result.BeforeUpdate = Get-MSYS2Version -Bash $BashPath -Fatal

    if ($PSCmdlet.ShouldProcess('MSYS2 package databases', 'Refresh')) {
        Write-Verbose -Message "Refreshing MSYS2 package databases: ${RefreshCmd}"
        $Refresh = Invoke-Pacman -Bash $BashPath -Arguments $RefreshArgs
        $Result.Refresh = $Refresh.Output
        $Result.ExitCode = $Refresh.ExitCode

        if ($Result.ExitCode -ne 0) {
            $ExcMsg = "pacman exited with non-zero exit code refreshing MSYS2 package databases: $($Result.ExitCode)"
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $RefreshCmd)
            $PSCmdlet.WriteError($ErrRec)
            return $Result
        }
    }

    if (!$PSCmdlet.ShouldProcess('MSYS2 runtime & packages', 'Update')) {
        $Result.WhatIf = $true

        Write-Verbose -Message "Listing upgradable MSYS2 packages (report only): ${UpgradeReportOnlyCmd}"
        $Upgrade = Invoke-Pacman -Bash $BashPath -Arguments $UpgradeReportOnlyArgs
        $Result.Upgrade = $Upgrade.Output
        $Result.ExitCode = $Upgrade.ExitCode

        # An exit code of 1 with no output indicates no upgradable packages
        if ($Result.ExitCode -eq 0 -or ($Result.ExitCode -eq 1 -and $Result.Upgrade.Count -eq 0)) {
            $Result.Success = $true
        } else {
            $ExcMsg = "pacman exited with non-zero exit code listing upgradable MSYS2 packages: $($Result.ExitCode)"
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpgradeReportOnlyCmd)
            $PSCmdlet.WriteError($ErrRec)
        }

        return $Result
    }

    Write-Verbose -Message "Upgrading MSYS2 packages: ${UpgradeCmd}"
    $Upgrade = Invoke-Pacman -Bash $BashPath -Arguments $UpgradeArgs
    $Result.Upgrade = $Upgrade.Output
    $Result.ExitCode = $Upgrade.ExitCode

    # A core system upgrade terminates all MSYS2 processes on completion, so
    # the exit code is not meaningful and the remaining packages are yet to be
    # upgraded. Run `pacman` again to perform the full system upgrade.
    $Result.AfterUpdate = Get-MSYS2Version -Bash $BashPath
    if ($Result.BeforeUpdate -ne $Result.AfterUpdate) {
        $Result.CoreUpgrade = $true

        Write-Verbose -Message "Upgrading MSYS2 packages after core system upgrade: ${UpgradeCmd}"
        $Upgrade = Invoke-Pacman -Bash $BashPath -Arguments $UpgradeArgs
        $Result.Upgrade += $Upgrade.Output
        $Result.ExitCode = $Upgrade.ExitCode
        $Result.AfterUpdate = Get-MSYS2Version -Bash $BashPath
    }

    if ($Result.ExitCode -eq 0) {
        $Result.Success = $true
    } else {
        $ExcMsg = "pacman exited with non-zero exit code upgrading MSYS2 packages: $($Result.ExitCode)"
        $ErrExc = [Exception]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpgradeCmd)
        $PSCmdlet.WriteError($ErrRec)
    }

    return $Result
}

#endregion

#region Perl

# Configure environment for Perl development
#
# Environment variables
# https://perldoc.perl.org/perlrun.html#ENVIRONMENT
Function Global:Switch-Perl {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Persist,
        [Switch]$Force
    )

    if (!(Test-IsPathFullyQualified -Path $Path)) {
        $Path = Join-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation -ChildPath $Path
    }

    $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
    if ($PathItem -isnot [IO.DirectoryInfo]) {
        $Msg = "Perl path is inaccessible or not a directory: ${Path}"

        if (!$Force) {
            $ErrExc = [ArgumentException]::new($Msg, 'Path')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Warning -Message $Msg
    }

    $Enable = !$Disable
    $PathChanges = [Collections.Generic.List[String]]::new()
    $PathParams = @{}
    $DirSepChars = [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar

    if ($Enable) {
        $PathFunc = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $PathChangesDesc = 'Prepended to PATH: '
    } else {
        $PathFunc = 'Remove-PathStringElement'
        $PathChangesDesc = 'Removed from PATH: '
    }

    $Path = [IO.Path]::GetFullPath($Path).TrimEnd($DirSepChars)

    $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'
    $PathChanges.Add($PerlBinPath)

    $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
    $PathChanges.Add($SiteBinPath)

    $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
    $PathChanges.Add($RootBinPath)

    if ($Env:PERL5LIB) {
        $LibBinPaths = [Collections.Generic.List[String]]::new()

        if ($Enable) {
            $LibPaths = [Collections.Generic.List[String]]::new()
        }

        foreach ($LibPath in $Env:PERL5LIB.Split([IO.Path]::PathSeparator)) {
            if ([String]::IsNullOrWhiteSpace($LibPath)) { continue }

            if (!(Test-IsPathFullyQualified -Path $LibPath)) {
                $ExcMsg = "Found not fully qualified path while parsing PERL5LIB: ${LibPath}"
                $ErrExc = [FormatException]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFullyQualified', $ErrCat, $LibPath)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            # Forward or backward slashes (or a mix) are valid for `PERL5LIB`
            $LibBasePathElements = $LibPath.Split($DirSepChars)
            if ($LibBasePathElements.Count -lt 3) {
                $ExcMsg = "Found path with less than expected minimum of 3 path components while parsing PERL5LIB: ${LibPath}"
                $ErrExc = [FormatException]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'InvalidPath', $ErrCat, $LibPath)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $LibBasePath = $LibBasePathElements[0..($LibBasePathElements.Count - 3)] -join '\'
            $LibBasePath = [IO.Path]::GetFullPath($LibBasePath)

            $LibBinPath = Join-Path -Path $LibBasePath -ChildPath 'bin'
            $LibBinPaths.Add($LibBinPath)

            if ($Enable) {
                $LibBasePathEsc = $LibBasePath.Replace('\', '\\')
                $LibPaths.Add($LibBasePathEsc)
            }
        }

        $PathChanges.AddRange($LibBinPaths)
    }

    foreach ($PathChange in $PathChanges) {
        $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $PathChange
        Write-Host -NoNewline -ForegroundColor 'Green' $PathChangesDesc
        Write-Host $PathChange
    }

    if ($Enable -and $Env:PERL5LIB -and $LibPaths.Count -ne 0) {
        # `Module::Build` options
        $Env:PERL_MB_OPT = '--install_base "{0}"' -f $LibPaths[0]
        Write-Host -NoNewline -ForegroundColor 'Green' 'Set PERL_MB_OPT to: '
        Write-Host $Env:PERL_MB_OPT

        # `ExtUtils::MakeMaker` options
        $Env:PERL_MM_OPT = 'INSTALL_BASE="{0}"' -f $LibPaths[0]
        Write-Host -NoNewline -ForegroundColor 'Green' 'Set PERL_MM_OPT to: '
        Write-Host $Env:PERL_MM_OPT
    } elseif ($Disable -and $IncludeNonPathVars) {
        $Env:PERL_MB_OPT = $null
        Write-Host -ForegroundColor 'Green' 'Unset PERL_MB_OPT.'

        $Env:PERL_MM_OPT = $null
        Write-Host -ForegroundColor 'Green' 'Unset PERL_MM_OPT.'
    }

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) {
            $PathParams['Action'] = 'Append'
        }

        if ($Env:PERL5LIB) {
            for ($i = $LibBinPaths.Count - 1; $i -ge 0; $i--) {
                Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
                    & $PathFunc @PathParams -Element $LibBinPaths[$i] |
                    Set-EnvironmentVariable -Name 'Path' -Scope 'User'
            }
        }

        Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
            & $PathFunc @PathParams -Element $RootBinPath |
            & $PathFunc @PathParams -Element $SiteBinPath |
            & $PathFunc @PathParams -Element $PerlBinPath |
            Set-EnvironmentVariable -Name 'Path' -Scope 'User'

        if ($Enable -and $Env:PERL5LIB -and $LibPaths.Count -ne 0) {
            Set-EnvironmentVariable -Name 'PERL_MB_OPT' -Value $Env:PERL_MB_OPT -Scope 'User'
            Set-EnvironmentVariable -Name 'PERL_MM_OPT' -Value $Env:PERL_MM_OPT -Scope 'User'
        } elseif ($Disable -and $IncludeNonPathVars) {
            Remove-EnvironmentVariable -Name 'PERL_MB_OPT' -Scope 'User'
            Remove-EnvironmentVariable -Name 'PERL_MM_OPT' -Scope 'User'
        }
    }
}

#endregion

#region Python

# Configure environment for Python development
#
# Environment variables
# https://docs.python.org/3/using/cmdline.html#environment-variables
Function Global:Switch-Python {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [ValidatePattern('^[0-9]+\.[0-9]+$')]
        [String]$Version,

        [Parameter(ParameterSetName = 'Enable')]
        [ValidateSet('Dev', 'UTF-8')]
        [String[]]$Features = @('UTF-8'),

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch]$IncludeNonPathVars,

        [Switch]$Persist,
        [Switch]$Force
    )

    if (!(Test-IsPathFullyQualified -Path $Path)) {
        $Path = Join-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation -ChildPath $Path
    }

    $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
    if ($PathItem -isnot [IO.DirectoryInfo]) {
        $Msg = "Python path is inaccessible or not a directory: ${Path}"

        if (!$Force) {
            $ErrExc = [ArgumentException]::new($Msg, 'Path')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Warning -Message $Msg
    }

    $Enable = !$Disable
    $PathChanges = [Collections.Generic.List[String]]::new()
    $PathParams = @{}
    $DirSepChars = [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar

    if ($Enable) {
        $PathFunc = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $PathChangesDesc = 'Prepended to PATH: '
    } else {
        $PathFunc = 'Remove-PathStringElement'
        $PathChangesDesc = 'Removed from PATH: '
    }

    $Path = [IO.Path]::GetFullPath($Path).TrimEnd($DirSepChars)
    $PathChanges.Add($Path)

    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
    $PathChanges.Add($ScriptsPath)

    if ($Env:PYTHONUSERBASE) {
        if (!(Test-IsPathFullyQualified -Path $Env:PYTHONUSERBASE)) {
            $ExcMsg = "PYTHONUSERBASE is not set to a fully qualified path: ${Env:PYTHONUSERBASE}"
            $ErrExc = [FormatException]::new($ExcMsg)
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
        try {
            $PythonExe = Join-Path -Path $Path -ChildPath 'python.exe'
            $VersionArgs = @('-V')
            $VersionCmd = "${PythonExe} $($VersionArgs -join ' ')"

            $PythonFailed = $false
            $PythonVersionRaw = (& $PythonExe @VersionArgs) -join ''
            if ($LASTEXITCODE -ne 0) {
                $PythonFailed = $true
                $ExcMsg = "Failed to retrieve Python version (rc: ${LASTEXITCODE})."
            }
        } catch {
            $PythonFailed = $true
            $ExcMsg = "Python executable missing or could not be executed: ${PythonExe}"
        } finally {
            if ($PythonFailed) {
                $ErrExc = [Exception]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $VersionCmd)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }
        }

        if ($PythonVersionRaw -notmatch '[0-9]+\.[0-9]+') {
            $ExcMsg = "Failed to extract Python version: ${PythonVersionRaw}"
            $ErrExc = [FormatException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ParserError
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
        Write-Host -NoNewline -ForegroundColor 'Green' $PathChangesDesc
        Write-Host $PathChange
    }

    # Python Development Mode
    $DevMode = $false
    if ($Features -contains 'Dev' -or $Disable) {
        if ($Enable) {
            if ($NativeVersion -ge '3.7') {
                $DevMode = $true
            } else {
                Write-Warning -Message 'Not enabling development mode as Python release is not >= 3.7.'
            }
        }

        if ($DevMode) {
            $Env:PYTHONDEVMODE = 1
            Write-Host -NoNewline -ForegroundColor 'Green' 'Set PYTHONDEVMODE to: '
            Write-Host $Env:PYTHONDEVMODE
        } elseif ($IncludeNonPathVars) {
            $Env:PYTHONDEVMODE = $null
            Write-Host -ForegroundColor 'Green' 'Unset PYTHONDEVMODE.'
        }
    }

    # UTF-8 mode (PEP 540)
    #
    # Default from Python 3.15 (PEP 686).
    $Utf8Mode = $false
    if ($Features -contains 'UTF-8' -or $Disable) {
        if ($Enable) {
            if ($NativeVersion -ge '3.7') {
                $Utf8Mode = $true
            } else {
                Write-Warning -Message 'Not enabling UTF-8 mode as Python release is not >= 3.7.'
            }
        }

        if ($Utf8Mode) {
            $Env:PYTHONUTF8 = 1
            Write-Host -NoNewline -ForegroundColor 'Green' 'Set PYTHONUTF8 to: '
            Write-Host $Env:PYTHONUTF8
        } elseif ($IncludeNonPathVars) {
            $Env:PYTHONUTF8 = $null
            Write-Host -ForegroundColor 'Green' 'Unset PYTHONUTF8.'
        }
    }

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
            & $PathFunc @PathParams -Element $LocalScriptsVersionedPath |
            & $PathFunc @PathParams -Element $LocalScriptsSharedPath |
            & $PathFunc @PathParams -Element $ScriptsPath |
            & $PathFunc @PathParams -Element $Path |
            Set-EnvironmentVariable -Name 'Path' -Scope 'User'

        if ($DevMode) {
            Set-EnvironmentVariable -Name 'PYTHONDEVMODE' -Value $Env:PYTHONDEVMODE -Scope 'User'
        }

        if ($Utf8Mode) {
            Set-EnvironmentVariable -Name 'PYTHONUTF8' -Value $Env:PYTHONUTF8 -Scope 'User'
        }

        if ($Disable -and $IncludeNonPathVars) {
            Remove-EnvironmentVariable -Name 'PYTHONDEVMODE' -Scope 'User'
            Remove-EnvironmentVariable -Name 'PYTHONUTF8' -Scope 'User'
        }
    }
}

# Update Python runtimes
Function Global:Update-Python {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param()

    Function Get-PythonRuntime {
        [CmdletBinding()]
        [OutputType([String[]])]
        Param()

        $ListArgs = 'list', '--format=json'
        $ListCmd = "pymanager $($ListArgs -join ' ')"

        Write-Verbose -Message "Listing Python runtimes: ${ListCmd}"
        $VersionsJsonRaw = @(& pymanager @ListArgs) -join ''
        if ($LASTEXITCODE -ne 0) {
            $ExcMsg = "Pymanager exited with non-zero exit code listing Python runtimes: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ListCmd)
            $PSCmdlet.WriteError($ErrRec)
            return [String[]]@($VersionsJsonRaw)
        }

        try {
            $VersionsJson = $VersionsJsonRaw | ConvertFrom-Json -ErrorAction 'Stop'
        } catch {
            $ExcMsg = "Failed to parse JSON listing Python runtimes: $($PSItem.Exception.Message)"
            $ErrExc = [Exception]::new($ExcMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'JsonParseFailed', $ErrCat, $VersionsJsonRaw)
            $PSCmdlet.WriteError($ErrRec)
            return [String[]]@($VersionsJsonRaw)
        }

        return [String[]]@($VersionsJson.versions.'display-name')
    }

    if (!(Get-Command -Name 'pymanager' -ErrorAction 'Ignore')) {
        $ExcMsg = 'Unable to update Python runtimes as pymanager command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ExcMsg)
        $ErrExc.CommandName = 'pymanager'
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'pymanager')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result = [PSCustomObject]@{
        Success      = $false
        BeforeUpdate = ''
        AfterUpdate  = ''
        Output       = [String[]]@()
        ExitCode     = -1
        WhatIf       = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.DevEnvWin.UpdatePython')

    $UpdateArgs = 'install', '--update'
    $UpdateCmd = "pymanager $($UpdateArgs -join ' ')"

    $Result.BeforeUpdate = Get-PythonRuntime

    $DryrunMsg = ''
    if (!$PSCmdlet.ShouldProcess('Python runtimes', 'Update')) {
        $DryrunMsg = ' (dry-run)'
        $UpdateArgs += '--dry-run'
        $UpdateCmd += ' --dry-run'
        $Result.WhatIf = $true
    }

    # Workaround for engine behaviour on PowerShell releases prior to 7.2. On
    # earlier releases, `$ErrorActionPreference` applies to redirected `stderr`
    # output from native commands, resulting in termination if set to `Stop`.
    $OriginalErrorActionPreference = $ErrorActionPreference

    Write-Verbose -Message "Updating Python runtimes${DryrunMsg}: ${UpdateCmd}"
    try {
        $ErrorActionPreference = 'Continue'
        $Result.Output = [String[]]@(& pymanager @UpdateArgs 2>&1)
        $Result.ExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $OriginalErrorActionPreference
    }

    if ($Result.ExitCode -eq 0) {
        $Result.Success = $true
    } else {
        $ExcMsg = "Pymanager exited with non-zero exit code updating Python runtimes: $($Result.ExitCode)"
        $ErrExc = [Exception]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateCmd)
        $PSCmdlet.WriteError($ErrRec)
    }

    if (!$WhatIfPreference) {
        $Result.AfterUpdate = Get-PythonRuntime
    }

    return $Result
}

#endregion

#region Windows

# Clear debugging symbols data
Function Global:Clear-SymbolData {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    $SymbolPaths = [Collections.Generic.List[String]]::new()

    $DefaultSymbolDirs = @(
        "${Env:SystemDrive}\Symbols"
        "${Env:SystemDrive}\SymCache"
        "${Env:ProgramData}\WindowsPerformanceRecorder\NGenPdbs_Cache"
        "${Env:LOCALAPPDATA}\RefSrcSymbols"
        "${Env:LOCALAPPDATA}\SourceServer"
        "${Env:LOCALAPPDATA}\SymbolSourceSymbols"
    )

    $SymbolPathEnvVars = '_NT_SYMBOL_PATH', '_NT_ALT_SYMBOL_PATH', '_NT_SYMCACHE_PATH'

    foreach ($SymbolPath in $DefaultSymbolDirs) {
        if (!(Test-IsPathFullyQualified -Path $SymbolPath)) {
            Write-Warning -Message "Ignoring relative default symbols path: ${SymbolPath}"
            continue
        }

        $PathItem = Get-Item -LiteralPath $SymbolPath -ErrorAction 'Ignore'
        if ($PathItem -is [IO.DirectoryInfo]) {
            $SymbolPaths.Add($SymbolPath)
        } elseif ($null -ne $PathItem) {
            Write-Warning -Message "Default symbols path is not a directory: ${SymbolPath}"
        }
    }

    foreach ($SymbolPathEnvVar in $SymbolPathEnvVars) {
        $SymbolPathEnvVarPath = "Env:\${SymbolPathEnvVar}"
        if (!(Test-Path -LiteralPath $SymbolPathEnvVarPath)) { continue }

        $SymbolPathEnvVarValue = (Get-Item -LiteralPath $SymbolPathEnvVarPath).Value
        if ($SymbolPathEnvVar -eq '_NT_SYMCACHE_PATH') {
            $SymbolPathEnvVarSeparator = '*'
        } else {
            $SymbolPathEnvVarSeparator = [IO.Path]::PathSeparator
        }

        foreach ($SymbolPath in $SymbolPathEnvVarValue.Split($SymbolPathEnvVarSeparator)) {
            if ([String]::IsNullOrWhiteSpace($SymbolPath)) { continue }

            if ($SymbolPathEnvVar -ne '_NT_SYMCACHE_PATH') {
                if ($SymbolPath -match '^srv\*(.+)\*.+' -or $SymbolPath -match '^cache\*(.+)') {
                    $SymbolPath = $Matches[1]
                }
            }

            if (!(Test-IsPathFullyQualified -Path $SymbolPath)) {
                Write-Warning -Message "Ignoring relative ${SymbolPathEnvVar} path: ${SymbolPath}"
                continue
            }

            if ($SymbolPath -match '^\\\\') {
                Write-Warning -Message "Ignoring UNC ${SymbolPathEnvVar} path: ${SymbolPath}"
                continue
            }

            $PathItem = Get-Item -LiteralPath $SymbolPath -ErrorAction 'Ignore'
            if ($PathItem -is [IO.DirectoryInfo]) {
                $SymbolPaths.Add($SymbolPath)
            } elseif ($null -ne $PathItem) {
                Write-Warning -Message "${SymbolPathEnvVar} path is not a directory: ${SymbolPath}"
            }
        }
    }

    foreach ($SymbolPath in $SymbolPaths) {
        $SymbolPath = '{0}{1}*' -f [WildcardPattern]::Escape($SymbolPath), [IO.Path]::DirectorySeparatorChar

        if ($PSCmdlet.ShouldProcess($SymbolPath, 'Clear')) {
            try {
                Remove-Item -Path $SymbolPath -Recurse -Force -ErrorAction 'Stop' -Verbose:$false
            } catch { $PSCmdlet.WriteError($PSItem) }
        }
    }
}

# Configure environment for Windows SDK tools
Function Global:Switch-WindowsSDK {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    [OutputType([Void])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [ValidateNotNullOrEmpty()]
        [Version]$Version,

        [ValidateSet('arm', 'arm64', 'x64', 'x86')]
        [String]$Architecture,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [Switch]$Disable,

        [Switch]$Persist,
        [Switch]$Force
    )

    $Is64BitOs = [Environment]::Is64BitOperatingSystem

    if (!$Path) {
        if ($Is64BitOs) {
            $Path = "${Env:ProgramFiles(x86)}\Windows Kits"
        } else {
            $Path = "${Env:ProgramFiles}\Windows Kits"
        }
    }

    if (!(Test-IsPathFullyQualified -Path $Path)) {
        $Path = Join-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation -ChildPath $Path
    }

    $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
    if ($PathItem -isnot [IO.DirectoryInfo]) {
        $Msg = "Windows SDK path is inaccessible or not a directory: ${Path}"

        if (!$Force) {
            $ErrExc = [ArgumentException]::new($Msg, 'Path')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Warning -Message $Msg
    }

    $Enable = !$Disable
    $PathParams = @{}
    $DirSepChars = [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar

    if ($Enable) {
        $PathFunc = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $PathChangesDesc = 'Prepended to PATH: '
    } else {
        $PathFunc = 'Remove-PathStringElement'
        $PathChangesDesc = 'Removed from PATH: '
    }

    $Path = [IO.Path]::GetFullPath($Path).TrimEnd($DirSepChars)

    if (!$Version) {
        $Version = [Environment]::OSVersion.Version
        Write-Host -NoNewline -ForegroundColor 'Green' 'Defaulting to Windows version as SDK version: '
        Write-Host $Version
    }

    if (!$Architecture) {
        $OriginalWhatIfPreference = $WhatIfPreference

        try {
            # The implicit import of the `CimCmdlets` module that may occur
            # triggers several "What if" outputs under Windows PowerShell. As
            # `Get-CimInstance` doesn't support `-WhatIf` and no state will be
            # modified we temporarily disable `WhatIf` mode.
            $WhatIfPreference = $false

            $Processor = Get-CimInstance -ClassName 'Win32_Processor' -ErrorAction 'Stop' -Verbose:$false | Select-Object -First 1
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        } finally {
            $WhatIfPreference = $OriginalWhatIfPreference
        }

        switch ($Processor.Architecture) {
            0 { $Architecture = 'x86' }
            5 { $Architecture = 'arm' }
            9 { if ($Is64BitOs) { $Architecture = 'x64' } else { $Architecture = 'x86' } }
            12 { if ($Is64BitOs) { $Architecture = 'arm64' } else { $Architecture = 'arm' } }

            default {
                $ExcMsg = "Unsupported processor architecture: $($Processor.Architecture)"
                $ErrExc = [NotSupportedException]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ProcessorNotSupported', $ErrCat, $Processor)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }
        }

        Write-Host -NoNewline -ForegroundColor 'Green' 'Defaulting to Windows processor architecture: '
        Write-Host $Architecture
    }

    if ($Version -lt '10.0') {
        $SdkVerPath = Join-Path -Path $Path -ChildPath "$($Version.ToString(2))\bin\${Architecture}"
    } else {
        $SdkVerPath = Join-Path -Path $Path -ChildPath "10\bin\${Version}\${Architecture}"
    }

    $SdkVerPathItem = Get-Item -LiteralPath $SdkVerPath -ErrorAction 'Ignore'
    if ($SdkVerPathItem -isnot [IO.DirectoryInfo]) {
        $Msg = "Windows SDK version path is inaccessible or not a directory: ${SdkVerPath}"

        if (!$Force) {
            $ErrExc = [ArgumentException]::new($Msg, 'Path')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $SdkVerPath)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Warning -Message $Msg
    }

    $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $SdkVerPath
    Write-Host -NoNewline -ForegroundColor 'Green' $PathChangesDesc
    Write-Host $SdkVerPath

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) {
            $PathParams['Action'] = 'Append'
        }

        Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
            & $PathFunc @PathParams -Element $SdkVerPath |
            Set-EnvironmentVariable -Name 'Path' -Scope 'User'
    }
}

#endregion

Complete-DotFilesSection
