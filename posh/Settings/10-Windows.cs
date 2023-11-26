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
