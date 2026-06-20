$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'Windows'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Switch to the user's profile directory if the current path is the Windows
# `System32` directory. The latter may be the default when launched elevated.
if ($PWD.Path -eq "${Env:SystemRoot}\System32") {
    Set-Location -LiteralPath $HOME
}

# Windows 10 releases starting with v1511 (TH1) include improved console VT100
# support. Applications can enable the support by calling `SetConsoleMode()`
# with the `ENABLE_VIRTUAL_TERMINAL_PROCESSING` console mode output flag. The
# improved VT100 support  can also be enabled by default by setting
# `VirtualTerminalLevel` (`REG_DWORD`) to `1` under the `HKCU\Console` key.
#
# This surfaces a bug in the Windows Console Host (`conhost.exe`). If the
# console is initialised with VT100 support enabled (i.e. without an initial
# transition from disabled to enabled) the tab stop width is incorrectly set.
# It appears to default to the number of columns in the console minus one,
# resulting in the first character of each line being right-justified.
#
# The bug is fixed in Windows 10 v2004 (20H1). An effective workaround for
# impacted releases is to call `SetConsoleMode()` to perform the required state
# transitions for the tab stop width to be correctly set.
#
# To avoid unnecessary P/Invoke calls and the associated type compilation,
# check if we're running on an affected configuration. This means all of:
# - Windows 10 v1511 through v1909
# - `VirtualTerminalLevel` is set to `1`
# - Not running under Windows Terminal (mitigated in v0.5.2661.0)
#
# References:
# - https://github.com/microsoft/WSL/issues/1173#issuecomment-254250445
# - https://github.com/microsoft/terminal/issues/1965#issuecomment-533290250
# - https://github.com/microsoft/terminal/pull/2816
Function Repair-ConHostVT100Bug {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Windows Terminal has its own mitigation (since v0.5.2661.0)
    if ($Env:WT_SESSION) { return }

    # Bug is only present in Windows builds 10586 through 19040
    try {
        $BuildNumber = [Int](Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction 'Stop' -Verbose:$false).BuildNumber
        if (!($BuildNumber -ge 10586 -and $BuildNumber -lt 19041)) { return }
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    # Bug only occurs if `VirtualTerminalLevel` setting is set to `1`
    try {
        $VirtualTerminalLevel = (Get-ItemProperty -LiteralPath 'HKCU:\Console' -Name 'VirtualTerminalLevel' -ErrorAction 'Ignore').VirtualTerminalLevel
        if ($VirtualTerminalLevel -ne 1) { return }
    } catch { return }

    Write-DotFilesMessage -Type 'Verbose' -Message 'Applying fix for ConHost VT100 tab stop width bug ...'

    if (!('DotFiles.Console' -as [Type])) {
        $ConsoleCode = Join-Path -Path $PSScriptRoot -ChildPath '10-Windows.cs'
        $ConsoleAPI = Get-Content -LiteralPath $ConsoleCode -Raw
        Add-Type -TypeDefinition $ConsoleAPI
    }

    # The `STD_INPUT_HANDLE` isn't relevant to this issue
    $ConStdHandleNames = 'STD_OUTPUT_HANDLE', 'STD_ERROR_HANDLE'
    foreach ($ConStdHandleName in $ConStdHandleNames) {
        Write-DotFilesMessage -Type 'Debug' -Message "Operating on console handle: ${ConStdHandleName}"
        $ConStdHandle = [DotFiles.Console]::GetStdHandle([DotFiles.Console+StdHandleDevices]::$ConStdHandleName)
        if ($ConStdHandle -eq -1) {
            $ErrExc = [ComponentModel.Win32Exception]::new()
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'Win32ApiFailed', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        [UInt32]$ConStdMode = 0
        if (!([DotFiles.Console]::GetConsoleMode($ConStdHandle, [Ref]$ConStdMode))) {
            $ErrExc = [ComponentModel.Win32Exception]::new()
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'Win32ApiFailed', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
        Write-DotFilesMessage -Type 'Debug' -Message "Current console output mode: $([DotFiles.Console+ConsoleModeOutputFlags]$ConStdMode)"

        $ConStdVT100 = [DotFiles.Console+ConsoleModeOutputFlags]$ConStdMode -band [DotFiles.Console+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING
        if (!$ConStdVT100) {
            Write-DotFilesMessage -Type 'Debug' -Message 'VT100 processing is not enabled on this handle.'
            continue
        }

        Write-DotFilesMessage -Type 'Debug' -Message 'Disabling console VT100 support ...'
        if (!([DotFiles.Console]::SetConsoleMode($ConStdHandle, [DotFiles.Console+ConsoleModeOutputFlags]$ConStdMode -bxor [DotFiles.Console+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING))) {
            $ErrExc = [ComponentModel.Win32Exception]::new()
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'Win32ApiFailed', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-DotFilesMessage -Type 'Debug' -Message 'Enabling console VT100 support ...'
        if (!([DotFiles.Console]::SetConsoleMode($ConStdHandle, [DotFiles.Console+ConsoleModeOutputFlags]$ConStdMode -bor [DotFiles.Console+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING))) {
            $ErrExc = [ComponentModel.Win32Exception]::new()
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'Win32ApiFailed', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

try {
    Repair-ConHostVT100Bug
} finally {
    Remove-Item -LiteralPath 'Function:\Repair-ConHostVT100Bug'
    Complete-DotFilesSection
}
