public const int INVALID_HANDLE_VALUE = -1;

public enum CreateFileCreationDisposition
{
    CREATE_NEW          = 1,
    CREATE_ALWAYS       = 2,
    OPEN_EXISTING       = 3,
    OPEN_ALWAYS         = 4,
    TRUNCATE_EXISTING   = 5
}

[Flags]
public enum CreateFileFlagsAndAttributes : uint
{
    FILE_ATTRIBUTE_READONLY         = 0x1,
    FILE_ATTRIBUTE_HIDDEN           = 0x2,
    FILE_ATTRIBUTE_SYSTEM           = 0x4,
    FILE_ATTRIBUTE_ARCHIVE          = 0x20,
    FILE_ATTRIBUTE_NORMAL           = 0x80,
    FILE_ATTRIBUTE_TEMPORARY        = 0x100,
    FILE_ATTRIBUTE_OFFLINE          = 0x1000,
    FILE_ATTRIBUTE_ENCRYPTED        = 0x4000,
    FILE_FLAG_OPEN_NO_RECALL        = 0x100000,
    FILE_FLAG_OPEN_REPARSE_POINT    = 0x200000,
    FILE_FLAG_SESSION_AWARE         = 0x800000,
    FILE_FLAG_POSIX_SEMANTICS       = 0x1000000,
    FILE_FLAG_BACKUP_SEMANTICS      = 0x2000000,
    FILE_FLAG_DELETE_ON_CLOSE       = 0x4000000,
    FILE_FLAG_SEQUENTIAL_SCAN       = 0x8000000,
    FILE_FLAG_RANDOM_ACCESS         = 0x10000000,
    FILE_FLAG_NO_BUFFERING          = 0x20000000,
    FILE_FLAG_OVERLAPPED            = 0x40000000,
    FILE_FLAG_WRITETHROUGH          = 0x80000000,
}

[Flags]
public enum GetFinalPathNameByHandleFlags
{
    VOLUME_NAME_DOS     = 0x0, // FILE_NAME_NORMALIZED
    VOLUME_NAME_GUID    = 0x1,
    VOLUME_NAME_NT      = 0x2,
    VOLUME_NAME_NONE    = 0x4,
    FILE_NAME_OPENED    = 0x8
}

[DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)]
public static extern bool CloseHandle(IntPtr hObject);

[DllImport("kernel32.dll", CharSet = CharSet.Unicode, EntryPoint = "CreateFileW", ExactSpelling = true, SetLastError = true)]
public static extern int CreateFile(
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
    uint lpMode
);
