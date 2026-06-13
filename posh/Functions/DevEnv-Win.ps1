$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Dev Env (Windows)'
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
Function Switch-Cygwin {
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

    $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
    if ($PathItem -isnot [IO.DirectoryInfo]) {
        $ErrMsg = "Cygwin path is inaccessible or not a directory: ${Path}"

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
    $UsrLocalBinPath = Join-Path -Path $Path -ChildPath 'usr\local\bin'

    $PathChanges = $BinPath, $UsrLocalBinPath
    foreach ($PathChange in $PathChanges) {
        $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $PathChange
        Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
        Write-Host $PathChange
    }

    if ($Enable -and $Symlinks -ne 'Default') {
        $CygwinCfg = [Collections.Generic.List[String]]::new()

        if ($Env:CYGWIN) {
            foreach ($Setting in $Env:CYGWIN.Split(' ')) {
                if ([String]::IsNullOrEmpty($Setting)) { continue }
                if ($Setting -notmatch 'winsymlinks') { $CygwinCfg.Add($Setting) }
            }
        }

        $CygwinCfg.Add("winsymlinks:$($Symlinks.ToLower())")
        $CygwinCfg.Sort()

        $Env:CYGWIN = $CygwinCfg -join ' '
        Write-Host -ForegroundColor 'Green' -NoNewline 'Set CYGWIN to: '
        Write-Host $Env:CYGWIN
    } elseif ($Disable -and $IncludeNonPathVars) {
        $Env:CYGWIN = ''
        Write-Host -ForegroundColor 'Green' 'Unset CYGWIN.'
    }

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) { $PathParams['Action'] = 'Append' }

        Get-EnvironmentVariable -Name 'Path' |
            & $PathFunc @PathParams -Element $UsrLocalBinPath |
            & $PathFunc @PathParams -Element $BinPath |
            Set-EnvironmentVariable -Name 'Path'

        if ($Enable -and ![String]::IsNullOrEmpty($Env:CYGWIN)) {
            Set-EnvironmentVariable -Name 'CYGWIN' -Value $Env:CYGWIN
        } elseif ($Disable -and $IncludeNonPathVars) {
            Set-EnvironmentVariable -Name 'CYGWIN' -Value ''
        }
    }
}

#endregion

#region Windows

# Configure environment for Windows SDK tools
Function Switch-WindowsSDK {
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

    $PathItem = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
    if ($PathItem -isnot [IO.DirectoryInfo]) {
        $ErrMsg = "Windows SDK path is inaccessible or not a directory: ${Path}"

        if (!$Force) {
            $ErrExc = [ArgumentException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Warning -Message $ErrMsg
    }

    $Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')

    if (!$Version) {
        $Version = [Environment]::OSVersion.Version
        Write-Host -ForegroundColor 'Green' -NoNewline 'Defaulting to Windows version as SDK version: '
        Write-Host $Version
    }

    if (!$Architecture) {
        # The implicit import of the `CimCmdlets` module that may occur below
        # triggers several "What if" outputs under Windows PowerShell, even
        # though `Get-Command` doesn't support `-WhatIf`. We can use
        # `$WhatIfPreference` to suppress them.
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
                $ErrMsg = "Unsupported processor architecture: $($Processor.Architecture)"
                $ErrExc = [NotSupportedException]::new($ErrMsg)
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
        $ErrMsg = "Windows SDK version path is inaccessible or not a directory: ${SdkVerPath}"

        if (!$Force) {
            $ErrExc = [ArgumentException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $SdkVerPath)
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

    $Env:Path = $Env:Path | & $PathFunc @PathParams -Element $SdkVerPath
    Write-Host -ForegroundColor 'Green' -NoNewline $PathChangesDesc
    Write-Host $SdkVerPath

    if ($Persist) {
        Write-Host -ForegroundColor 'Green' 'Persisting changes to user environment ...'
        if ($Enable) { $PathParams['Action'] = 'Append' }

        Get-EnvironmentVariable -Name 'Path' |
            & $PathFunc @PathParams -Element $SdkVerPath |
            Set-EnvironmentVariable -Name 'Path'
    }
}

#endregion

Complete-DotFilesSection
