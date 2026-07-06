using System;
using System.Runtime.InteropServices;

namespace DotFiles
{
    public static class FinalPath
    {
        public const int INVALID_HANDLE_VALUE = -1;

        public enum CreateFileCreationDisposition : uint
        {
            CREATE_NEW        = 1,
            CREATE_ALWAYS     = 2,
            OPEN_EXISTING     = 3,
            OPEN_ALWAYS       = 4,
            TRUNCATE_EXISTING = 5
        }

        [Flags]
        public enum CreateFileFlagsAndAttributes : uint
        {
            // File attributes
            FILE_ATTRIBUTE_READONLY              = 0x1,
            FILE_ATTRIBUTE_HIDDEN                = 0x2,
            FILE_ATTRIBUTE_SYSTEM                = 0x4,
            FILE_ATTRIBUTE_DIRECTORY             = 0x10,
            FILE_ATTRIBUTE_ARCHIVE               = 0x20,
            FILE_ATTRIBUTE_DEVICE                = 0x40,
            FILE_ATTRIBUTE_NORMAL                = 0x80,
            FILE_ATTRIBUTE_TEMPORARY             = 0x100,
            FILE_ATTRIBUTE_SPARSE_FILE           = 0x200,
            FILE_ATTRIBUTE_REPARSE_POINT         = 0x400,
            FILE_ATTRIBUTE_COMPRESSED            = 0x800,
            FILE_ATTRIBUTE_OFFLINE               = 0x1000,
            FILE_ATTRIBUTE_NOT_CONTENT_INDEXED   = 0x2000,
            FILE_ATTRIBUTE_ENCRYPTED             = 0x4000,
            FILE_ATTRIBUTE_INTEGRITY_STREAM      = 0x8000,
            FILE_ATTRIBUTE_VIRTUAL               = 0x10000,
            FILE_ATTRIBUTE_NO_SCRUB_DATA         = 0x20000,
            FILE_ATTRIBUTE_EA                    = 0x40000,
            FILE_ATTRIBUTE_RECALL_ON_OPEN        = 0x40000,
            FILE_ATTRIBUTE_PINNED                = 0x80000,
            FILE_ATTRIBUTE_UNPINNED              = 0x100000,
            FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x400000,
            FILE_ATTRIBUTE_STRICTLY_SEQUENTIAL   = 0x20000000,

            // File flags
            FILE_FLAG_DISALLOW_PATH_REDIRECTS       = 0x10000,
            FILE_FLAG_IGNORE_IMPERSONATED_DEVICEMAP = 0x20000,
            FILE_FLAG_OPEN_REQUIRING_OPLOCK         = 0x40000,
            FILE_FLAG_FIRST_PIPE_INSTANCE           = 0x80000,
            FILE_FLAG_OPEN_NO_RECALL                = 0x100000,
            FILE_FLAG_OPEN_REPARSE_POINT            = 0x200000,
            FILE_FLAG_SESSION_AWARE                 = 0x800000,
            FILE_FLAG_POSIX_SEMANTICS               = 0x1000000,
            FILE_FLAG_BACKUP_SEMANTICS              = 0x2000000,
            FILE_FLAG_DELETE_ON_CLOSE               = 0x4000000,
            FILE_FLAG_SEQUENTIAL_SCAN               = 0x8000000,
            FILE_FLAG_RANDOM_ACCESS                 = 0x10000000,
            FILE_FLAG_NO_BUFFERING                  = 0x20000000,
            FILE_FLAG_OVERLAPPED                    = 0x40000000,
            FILE_FLAG_WRITE_THROUGH                 = 0x80000000
        }

        [Flags]
        public enum GetFinalPathNameByHandleFlags : uint
        {
            FILE_NAME_NORMALIZED = 0x0,
            FILE_NAME_OPENED     = 0x8,
            VOLUME_NAME_DOS      = 0x0,
            VOLUME_NAME_GUID     = 0x1,
            VOLUME_NAME_NT       = 0x2,
            VOLUME_NAME_NONE     = 0x4
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, EntryPoint = "CreateFileW", ExactSpelling = true, SetLastError = true)]
        public static extern IntPtr CreateFile(
            [MarshalAs(UnmanagedType.LPWStr)] string lpFileName,
            uint dwDesiredAccess,
            uint dwShareMode,
            uint lpSecurityAttributes,
            uint dwCreationDisposition,
            uint dwFlagsAndAttributes,
            IntPtr hTemplateFile
        );

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, EntryPoint = "GetFinalPathNameByHandleW", ExactSpelling = true, SetLastError = true)]
        public static extern uint GetFinalPathNameByHandle(
            IntPtr hFile,
            System.Text.StringBuilder lpszFilePath,
            uint cchFilePath,
            uint dwFlags
        );
    }
}
