if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing environment functions (Windows only) ...')

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

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $Path = [IO.Path]::GetFullPath($Path)
    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    $LocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $BinPath |
        & $Operation @PathParams -Element $LocalBinPath

    $CygwinCfg = [Collections.Generic.List[String]]::new()
    if ($env:CYGWIN) {
        foreach ($Setting in $env:CYGWIN.Split(' ')) {
            if ([String]::IsNullOrEmpty($Setting)) {
                continue
            }

            if ($Setting -notmatch 'winsymlinks') {
                $CygwinCfg.Add($Setting)
            }
        }
    }

    if ($Symlinks -ne 'Default') {
        $CygwinCfg.Add('winsymlinks:{0}' -f $Symlinks.ToLower())
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

    $PathParams = @{}
    if (!$Disable) {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
    } else {
        $Operation = 'Remove-PathStringElement'
    }

    $Path = [IO.Path]::GetFullPath($Path)

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
            Set-EnvironmentVariable @EnvParams
    }
}

#endregion
