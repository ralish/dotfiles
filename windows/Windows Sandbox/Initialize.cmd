@ECHO OFF

@REM Switch to batch file directory
CD /D "%~dp0"

@REM File Explorer options
@REM General -> Open File Explorer to: This PC
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f
@REM General -> Privacy -> Show recently used files
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 0 /f
@REM General -> Privacy -> Show frequently used folders
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowFrequent /t REG_DWORD /d 0 /f
@REM General -> Privacy -> Show files from Office.com
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowCloudFilesInQuickAccess /t REG_DWORD /d 0 /f
@REM General -> Privacy -> Include account-based insights, recent, favourite, and recommended files
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecommendations /t REG_DWORD /d 0 /f
@REM View -> Files and Folders -> Hidden files and folders -> Show hidden files, folders and drives
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f
@REM View -> Files and Folders -> Hide empty drives
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideDrivesWithNoMedia /t REG_DWORD /d 0 /f
@REM View -> Files and Folders -> Hide extensions for known file types
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f
@REM View -> Files and Folders -> Hide folder merge conflicts
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideMergeConflicts /t REG_DWORD /d 0 /f
@REM View -> Files and Folders -> Show encrypted or compressed NTFS files in colour
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowEncryptCompressedColor /t REG_DWORD /d 1 /f
@REM View -> Files and Folders -> Show sync provider notifications
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSyncProviderNotifications /t REG_DWORD /d 0 /f
@REM View -> Files and Folders -> Use Sharing Wizard
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v SharingWizardOn /t REG_DWORD /d 0 /f
@REM View -> Navigation pane -> Expand to open folder
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v NavPaneExpandToCurrentFolder /t REG_DWORD /d 1 /f
@REM View -> Navigation pane -> Show all folders
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v NavPaneShowAllFolders /t REG_DWORD /d 1 /f

@REM Add Sysinternals to system path
FOR /F "usebackq tokens=2,*" %%A IN (`REG QUERY "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path`) DO SET PATH_MACHINE=%%B
SETX /M PATH "%PATH_MACHINE%;%ProgramFiles(x86)%\Sysinternals"

@REM Process Monitor options
@REM Filter -> Drop Filtered Events
REG ADD "HKCU\Software\Sysinternals\Process Monitor" /v DestructiveFilter /t REG_DWORD /d 1 /f
