if (!(Test-IsWindows)) {
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading Windows settings ...')

# Windows 10 releases starting with 1511 (Threshold 1) include improved
# console VT100 support. Applications can enable the support by calling
# SetConsoleMode() with the ENABLE_VIRTUAL_TERMINAL_PROCESSING flag. It
# can also be enabled by default for all console applications by setting
# VirtualTerminalLevel (REG_DWORD) to 1 under the HKCU:\Console key.
#
# This surfaces a subtle bug in the Windows Console Host (conhost.exe).
# If the console is initialised with VT100 support enabled (i.e. there
# is no transition from not enabled to enabled), the default tab stop
# width is not correctly set. It appears to default to the number of
# columns in the console minus one? Thus, the first character of each
# line will appear to be "right-aligned".
#
# Apparently the bug is fixed in the 2004 (20H1) release. Until then, a
# workaround is to use P/Invoke and call SetConsoleMode() to perform the
# required VT100 state transitions for tab stops to be correctly set.
#
# To avoid unnecessary P/Invoke calls and associated type compilation
# check if we're running an affected configuration. This means all of:
# - Windows 10 1511 through 1909
# - VirtualTerminalLevel is set to 1
# - Not running under Windows Terminal (mitigated since v0.5.2661.0)
#
# The fact I bothered to implement this workaround is fairly persuasive
# evidence that I may, in fact, be completely insane.
#
# References:
# - https://github.com/Microsoft/WSL/issues/1173#issuecomment-254250445
# - https://github.com/microsoft/terminal/issues/1965#issuecomment-533290250
# - https://github.com/microsoft/terminal/pull/2816
if (!$env:WT_SESSION) {
    $BuildNumber = [int](Get-CimInstance -ClassName Win32_OperatingSystem -Verbose:$false).BuildNumber

    if ($BuildNumber -ge 10586 -and $BuildNumber -lt 19041) {
        if ((Get-ItemProperty -Path HKCU:\Console -Name VirtualTerminalLevel -ErrorAction SilentlyContinue).VirtualTerminalLevel) {
            $ConHostVT100Bug = $true
        }
    }

    Remove-Variable -Name BuildNumber
}

if ($ConHostVT100Bug) {
    $ConHostVT100Fix = {
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

        if (!('DotFiles.ConsoleAPI' -as [Type])) {
            Add-Type -Namespace DotFiles -Name ConsoleAPI -MemberDefinition $ConsoleAPI
        }

        # The STD_INPUT_HANDLE shouldn't be relevant to this issue
        $ConStdHandleNames = @('STD_OUTPUT_HANDLE', 'STD_ERROR_HANDLE')
        foreach ($ConStdHandleName in $ConStdHandleNames) {
            Write-Debug -Message (Get-DotFilesMessage -Message ('Operating on console handle: {0}' -f $ConStdHandleName))
            $ConStdHandle = [DotFiles.ConsoleAPI]::GetStdHandle([DotFiles.ConsoleAPI+StdHandleDevices]::$ConStdHandleName)
            if ($ConStdHandle -eq -1) {
                throw (New-Object -TypeName ComponentModel.Win32Exception)
            }

            [uint32]$ConStdMode = 0
            if (!([DotFiles.ConsoleAPI]::GetConsoleMode($ConStdHandle, [ref]$ConStdMode))) {
                throw (New-Object -TypeName ComponentModel.Win32Exception)
            }
            Write-Debug -Message (Get-DotFilesMessage -Message ('Current console output mode: {0}' -f [DotFiles.ConsoleAPI+ConsoleModeOutputFlags]$ConStdMode))

            $ConStdVT100 = [DotFiles.ConsoleAPI+ConsoleModeOutputFlags]$ConStdMode -band [DotFiles.ConsoleAPI+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING
            if ($ConStdVT100) {
                Write-Debug -Message (Get-DotFilesMessage -Message 'Disabling console VT100 support ...')
                if (!([DotFiles.ConsoleAPI]::SetConsoleMode($ConStdHandle, [DotFiles.ConsoleAPI+ConsoleModeOutputFlags]$ConStdMode -bxor [DotFiles.ConsoleAPI+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING))) {
                    throw (New-Object -TypeName ComponentModel.Win32Exception)
                }

                Write-Debug -Message (Get-DotFilesMessage -Message 'Enabling console VT100 support ...')
                if (!([DotFiles.ConsoleAPI]::SetConsoleMode($ConStdHandle, [DotFiles.ConsoleAPI+ConsoleModeOutputFlags]$ConStdMode -bor [DotFiles.ConsoleAPI+ConsoleModeOutputFlags]::ENABLE_VIRTUAL_TERMINAL_PROCESSING))) {
                    throw (New-Object -TypeName ComponentModel.Win32Exception)
                }
            } else {
                Write-Debug -Message (Get-DotFilesMessage -Message 'VT100 processing not enabled on this handle.')
            }
        }
    }

    Write-Verbose -Message (Get-DotFilesMessage -Message 'Applying fix for ConHost VT100 tab stop width bug ...')
    $ConHostVT100Fix.Invoke()
    Remove-Variable -Name @('ConHostVT100Bug', 'ConHostVT100Fix')
}
