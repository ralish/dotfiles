$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Environments (Windows)'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

#region Cygwin

# Configure environment for Cygwin usage
#
# Environment variables
# https://cygwin.com/cygwin-ug-net/setup-env.html
#
# Input environment variables
# - CYGWIN (optional)
#   List of global Cygwin runtime settings (space-separated).
Function Switch-Cygwin {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path = "$env:HOMEDRIVE\DevEnvs\Cygwin",

        [ValidateSet('Default', 'Lnk', 'Native', 'NativeStrict')]
        [String]$Symlinks = 'NativeStrict',

        [Switch]$Persist,
        [Switch]$Disable
    )

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Cygwin path is not a directory: {0}' -f $Path
    }

    $PathParams = @{}
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
        $PathChangesDesc = 'Removed from PATH: '
    } else {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $PathChangesDesc = 'Prepended to PATH: '
    }

    $Path = [IO.Path]::GetFullPath($Path)
    $BinPath = Join-Path -Path $Path -ChildPath 'bin'
    $UsrLocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'
    $PathChanges = @($UsrLocalBinPath, $BinPath)

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $BinPath |
        & $Operation @PathParams -Element $UsrLocalBinPath

    foreach ($PathChange in $PathChanges) {
        Write-Host -ForegroundColor Green -NoNewline $PathChangesDesc
        Write-Host $PathChange
    }

    $CygwinCfg = [Collections.Generic.List[String]]::new()
    if ($env:CYGWIN) {
        foreach ($Setting in $env:CYGWIN.Split(' ')) {
            if ([String]::IsNullOrEmpty($Setting)) { continue }
            if ($Setting -notmatch 'winsymlinks') { $CygwinCfg.Add($Setting) }
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
        $EnvParams = @{ Name = 'Path' }

        if (!$Disable) { $PathParams['Action'] = 'Append' }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $UsrLocalBinPath |
            & $Operation @PathParams -Element $BinPath |
            Set-EnvironmentVariable @EnvParams

        if (!$Disable) {
            Set-EnvironmentVariable -Name 'CYGWIN' -Value ($CygwinCfg -join ' ')
        }
    }
}

#endregion

#region Windows

# Configure environment for Windows SDK tools
Function Switch-WindowsSDK {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [ValidateNotNullOrEmpty()]
        [Version]$Version,

        [Switch]$Persist,
        [Switch]$Disable
    )

    $Is64BitOs = [Environment]::Is64BitOperatingSystem

    if (!$Path) {
        if ($Is64BitOs) {
            $Path = "${Env:ProgramFiles(x86)}\Windows Kits"
        } else {
            $Path = "$Env:ProgramFiles\Windows Kits"
        }
    }

    if (!$Disable -and !(Test-Path -LiteralPath $Path -PathType Container)) {
        throw 'Windows SDK path is not a directory: {0}' -f $Path
    }

    $Path = [IO.Path]::GetFullPath($Path)

    $Processor = Get-CimInstance -ClassName 'Win32_Processor' -Verbose:$false
    switch ($Processor.Architecture) {
        0 { $ArchName = 'x86' }
        5 { $ArchName = 'arm' }
        9 { if ($Is64BitOs) { $ArchName = 'x64' } else { $ArchName = 'x86' } }
        12 { if ($Is64BitOs) { $ArchName = 'arm64' } else { $ArchName = 'arm' } }
        default { throw 'Unsupported processor architecture: {0}' -f $Processor.Architecture }
    }

    if (!$Version) {
        $Version = [Environment]::OSVersion.Version
        Write-Host -ForegroundColor Green -NoNewline 'Defaulting to Windows version as SDK version: '
        Write-Host $Version
    }

    if ($Version -lt '10.0') {
        $SdkVerPath = Join-Path -Path $Path -ChildPath ('{0}\bin\{1}' -f $Version.ToString(2), $ArchName)
    } else {
        $SdkVerPath = Join-Path -Path $Path -ChildPath ('10\bin\{0}\{1}' -f $Version, $ArchName)
    }

    if (!$Disable -and !(Test-Path -LiteralPath $SdkVerPath -PathType Container)) {
        throw 'Resolved Windows SDK version path is not a directory: {0}' -f $SdkVerPath
    }

    $PathParams = @{}
    if ($Disable) {
        $Operation = 'Remove-PathStringElement'
        $PathChangesDesc = 'Removed from PATH: '
    } else {
        $Operation = 'Add-PathStringElement'
        $PathParams['Action'] = 'Prepend'
        $PathChangesDesc = 'Prepended to PATH: '
    }

    $env:Path = $env:Path |
        & $Operation @PathParams -Element $SdkVerPath

    Write-Host -ForegroundColor Green -NoNewline $PathChangesDesc
    Write-Host $SdkVerPath

    if ($Persist) {
        $EnvParams = @{ Name = 'Path' }

        if (!$Disable) { $PathParams['Action'] = 'Append' }

        Get-EnvironmentVariable @EnvParams |
            & $Operation @PathParams -Element $SdkVerPath |
            Set-EnvironmentVariable @EnvParams
    }
}

#endregion

Complete-DotFilesSection
