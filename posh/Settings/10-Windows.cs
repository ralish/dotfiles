using System;
using System.Runtime.InteropServices;

namespace DotFiles
{
    public static class Console
    {
        [Flags]
        public enum ConsoleModeInputFlags : uint
        {
            ENABLE_PROCESSED_INPUT        = 0x1,
            ENABLE_LINE_INPUT             = 0x2,
            ENABLE_ECHO_INPUT             = 0x4,
            ENABLE_WINDOW_INPUT           = 0x8,
            ENABLE_MOUSE_INPUT            = 0x10,
            ENABLE_INSERT_MODE            = 0x20,
            ENABLE_QUICK_EDIT_MODE        = 0x40,
            ENABLE_EXTENDED_FLAGS         = 0x80,
            ENABLE_AUTO_POSITION          = 0x100,
            ENABLE_VIRTUAL_TERMINAL_INPUT = 0x200
        }

        [Flags]
        public enum ConsoleModeOutputFlags : uint
        {
            ENABLE_PROCESSED_OUTPUT            = 0x1,
            ENABLE_WRAP_AT_EOL_OUTPUT          = 0x2,
            ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x4,
            DISABLE_NEWLINE_AUTO_RETURN        = 0x8,
            ENABLE_LVB_GRID_WORLDWIDE          = 0x10
        }

        public enum StdHandleDevices : uint
        {
            STD_INPUT_HANDLE  = 4294967286, // ((DWORD)-10)
            STD_OUTPUT_HANDLE = 4294967285, // ((DWORD)-11)
            STD_ERROR_HANDLE  = 4294967284  // ((DWORD)-12)
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetConsoleMode(
            IntPtr hConsoleHandle,
            out uint lpMode
        );

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(
            uint nStdHandle
        );

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetConsoleMode(
            IntPtr hConsoleHandle,
            uint dwMode
        );
    }
}
