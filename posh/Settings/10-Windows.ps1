$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'Windows'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Switch to the user profile directory if the current path is the Windows
# System32 directory. This probably means we were launched elevated.
if ($PWD.Path -eq "$env:SystemRoot\System32") {
    Set-Location -Path $HOME
}

# Windows 10 releases starting with v1511 (TH1) include improved console VT100
# support. Applications enable the support by calling SetConsoleMode() with the
# ENABLE_VIRTUAL_TERMINAL_PROCESSING flag. It can also be enabled by default by
# setting VirtualTerminalLevel (REG_DWORD) to 1 under the HKCU:\Console key.
#
# This surfaces a subtle bug in the Windows Console Host (conhost.exe). If the
# console is initialised with VT100 support enabled (i.e. there's no transition
# from disabled to enabled) the default tab stop width is not correctly set. It
# appears to default to the number of columns in the console minus one, giving
# the appearance of the first character of each line being right-justified.
#
# The bug is fixed in the v2004 (20H1) release. Until then, a workaround is to
# call SetConsoleMode() via P/Invoke to perform the required state transitions
# for the tab stop width to be correctly set.
#
# To avoid unnecessary P/Invoke calls and associated type compilation, check if
# we're running an affected configuration. This means all of:
# - Windows 10 v1511 through v1909
# - VirtualTerminalLevel is set to 1
# - Not running under Windows Terminal (mitigated since v0.5.2661.0)
#
# References:
# - https://github.com/Microsoft/WSL/issues/1173#issuecomment-254250445
# - https://github.com/microsoft/terminal/issues/1965#issuecomment-533290250
# - https://github.com/microsoft/terminal/pull/2816
Function Repair-ConHostVT100Bug {
    [CmdletBinding()]
    Param()

    # Windows Terminal has its own mitigation (since v0.5.2661.0)
    if ($env:WT_SESSION) {
        return
    }

    # Bug only present in Windows builds 10586 through 19040
    $BuildNumber = [int](Get-CimInstance -ClassName Win32_OperatingSystem -Verbose:$false).BuildNumber
    if (!($BuildNumber -ge 10586 -and $BuildNumber -lt 19041)) {
        return
    }

    # Bug only occurs if VirtualTerminalLevel setting is set to 1
    $VirtualTerminalLevel = (Get-ItemProperty -LiteralPath HKCU:\Console -Name VirtualTerminalLevel -ErrorAction SilentlyContinue).VirtualTerminalLevel
    if ($VirtualTerminalLevel -ne 1) {
        return
    }

    Write-Verbose -Message (Get-DotFilesMessage -Message 'Applying fix for ConHost VT100 tab stop width bug ...')

    $ConsoleAPI = @'
[Flags]
public enum ConsoleModeInputFlags
{
    ENABLE_PROCESSED_INPUT          = 0x001,
    ENABLE_LINE_INPUT               = 0x002,
    ENABLE_ECHO_INPUT               = 0x004,
    ENABLE_WINDOW_INPUT             = 0x008,
    ENABLE_MOUSE_INPUT              = 0x010,
    ENABLE_INSERT_MODE              = 0x020,
    ENABLE_QUICK_EDIT_MODE          = 0x040,
    ENABLE_EXTENDED_FLAGS           = 0x080,
    ENABLE_AUTO_POSITION            = 0x100,
    ENABLE_VIRTUAL_TERMINAL_INPUT   = 0x200
}

[Flags]
public enum ConsoleModeOutputFlags
{
    ENABLE_PROCESSED_OUTPUT             = 0x01,
    ENABLE_WRAP_AT_EOL_OUTPUT           = 0x02,
    ENABLE_VIRTUAL_TERMINAL_PROCESSING  = 0x04,
    DISABLE_NEWLINE_AUTO_RETURN         = 0x08,
    ENABLE_LVB_GRID_WORLDWIDE           = 0x10
}

[Flags]
public enum StdHandleDevices
{
    STD_INPUT_HANDLE    = -10,
    STD_OUTPUT_HANDLE   = -11,
    STD_ERROR_HANDLE    = -12
}

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(
    IntPtr hConsoleHandle,
    out uint lpMode
);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(
    int nStdHandle
);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(
    IntPtr hConsoleHandle,
    uint dwMode
);
'@

    if (!('DotFiles.Console' -as [Type])) {
        Add-Type -Namespace DotFiles -Name Console -MemberDefinition $ConsoleAPI
    }

    # The STD_INPUT_HANDLE shouldn't be relevant to this issue
    $ConStdHandleNames = 'STD_OUTPUT_HANDLE', 'STD_ERROR_HANDLE'
    foreach ($ConStdHandleName in $ConStdHandleNames) {
        Write-Debug -Message (Get-DotFilesMessage -Message ('Operating on console handle: {0}' -f $ConStdHandleName))
        $ConStdHandle = [DotFiles.Console]::GetStdHandle([DotFiles.Console+StdHandleDevices]::$ConStdHandleName)
        if ($ConStdHandle -eq -1) {
            throw [ComponentModel.Win32Exception]::new()
        }

        [uint32]$ConStdMode = 0
        if (!([DotFiles.Console]::GetConsoleMode($ConStdHandle, [ref]$ConStdMode))) {
            throw [ComponentModel.Win32Exception]::new()
        }
        Write-Debug -Message (Get-DotFilesMessage -Message ('Current console output mode: {0}' -f [DotFiles.Console+ConsoleModeOutputFlags]$ConStdMode))

        $ConStdVT100 = [DotFiles.Console+ConsoleModeOutputFlags]$ConStdMode -band [DotFiles.Console+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING
        if ($ConStdVT100) {
            Write-Debug -Message (Get-DotFilesMessage -Message 'Disabling console VT100 support ...')
            if (!([DotFiles.Console]::SetConsoleMode($ConStdHandle, [DotFiles.Console+ConsoleModeOutputFlags]$ConStdMode -bxor [DotFiles.Console+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING))) {
                throw [ComponentModel.Win32Exception]::new()
            }

            Write-Debug -Message (Get-DotFilesMessage -Message 'Enabling console VT100 support ...')
            if (!([DotFiles.Console]::SetConsoleMode($ConStdHandle, [DotFiles.Console+ConsoleModeOutputFlags]$ConStdMode -bor [DotFiles.Console+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING))) {
                throw [ComponentModel.Win32Exception]::new()
            }
        } else {
            Write-Debug -Message (Get-DotFilesMessage -Message 'VT100 processing not enabled on this handle.')
        }
    }
}

Repair-ConHostVT100Bug

Remove-Item -Path Function:\Repair-ConHostVT100Bug
Complete-DotFilesSection
