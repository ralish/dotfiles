$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Dev Env (Windows)'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

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
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
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
        Write-Host -ForegroundColor 'Green' -NoNewline 'Set CYGWIN to: '
        Write-Host $Env:CYGWIN
    } elseif ($Disable -and $IncludeNonPathVars) {
        $Env:CYGWIN = $null
        Write-Host -ForegroundColor 'Green' 'Unset CYGWIN.'
    }

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) { $PathParams['Action'] = 'Append' }

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

            $LibBasePathElements = $LibPath.Split('\')
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
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
        Write-Host $PathChange
    }

    if ($Enable -and $Env:PERL5LIB -and $LibPaths.Count -ne 0) {
        # Extra options for `Module::Build`
        $Env:PERL_MB_OPT = "--install_base '$($LibPaths[0])'"
        Write-Host -ForegroundColor 'Green' -NoNewline 'Set PERL_MB_OPT to: '
        Write-Host $Env:PERL_MB_OPT

        # Extra options for `ExtUtils::MakeMaker`
        $Env:PERL_MM_OPT = "INSTALL_BASE=`"$($LibPaths[0])`""
        Write-Host -ForegroundColor 'Green' -NoNewline 'Set PERL_MM_OPT to: '
        Write-Host $Env:PERL_MM_OPT
    } elseif ($Disable -and $IncludeNonPathVars) {
        $Env:PERL_MB_OPT = $null
        Write-Host -ForegroundColor 'Green' 'Unset PERL_MB_OPT.'

        $Env:PERL_MM_OPT = $null
        Write-Host -ForegroundColor 'Green' 'Unset PERL_MM_OPT.'
    }

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) { $PathParams['Action'] = 'Append' }

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

        if ($Enable -and ![String]::IsNullOrWhiteSpace($Env:PERL5LIB)) {
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
            $PythonVersionRaw = (& $PythonExe @VersionArgs 2>&1) -join ''
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
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
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
            Write-Host -ForegroundColor 'Green' -NoNewline 'Set PYTHONDEVMODE to: '
            Write-Host $Env:PYTHONDEVMODE
        } elseif ($IncludeNonPathVars) {
            $Env:PYTHONDEVMODE = $null
            Write-Host -ForegroundColor 'Green' 'Unset PYTHONDEVMODE.'
        }
    }

    # UTF-8 Mode (see PEP 540)
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
            Write-Host -ForegroundColor 'Green' -NoNewline 'Set PYTHONUTF8 to: '
            Write-Host $Env:PYTHONUTF8
        } elseif ($IncludeNonPathVars) {
            $Env:PYTHONUTF8 = $null
            Write-Host -ForegroundColor 'Green' 'Unset PYTHONUTF8.'
        }
    }

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) { $PathParams['Action'] = 'Append' }

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

#endregion

#region Windows

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
        Write-Host -ForegroundColor 'Green' -NoNewline 'Defaulting to Windows version as SDK version: '
        Write-Host $Version
    }

    if (!$Architecture) {
        # The implicit import of the `CimCmdlets` module that may occur below
        # triggers several "What if" outputs under Windows PowerShell, even
        # though `Get-CimInstance` doesn't support `-WhatIf`. As this cmdlet
        # doesn't modify any state we temporarily disable `WhatIf` mode.
        try {
            $WhatIfOriginal = $WhatIfPreference
            $WhatIfPreference = $false

            $Processor = Get-CimInstance -ClassName 'Win32_Processor' -ErrorAction 'Stop' -Verbose:$false | Select-Object -First 1
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        } finally {
            $WhatIfPreference = $WhatIfOriginal
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

        Write-Host -ForegroundColor 'Green' -NoNewline 'Defaulting to Windows processor architecture: '
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
    Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
    Write-Host $SdkVerPath

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) { $PathParams['Action'] = 'Append' }

        Get-EnvironmentVariable -Name 'Path' -Scope 'User' |
            & $PathFunc @PathParams -Element $SdkVerPath |
            Set-EnvironmentVariable -Name 'Path' -Scope 'User'
    }
}

#endregion

Complete-DotFilesSection
