@ECHO OFF
ECHO Making Command Prompt suck slightly less...

REM So that we can safely run via AutoRun
REM Use something like: IF NOT DEFINED SetupEnv Path\To\SetupEnv.Cmd
SET SetupEnv=Yes

REM Uncomment to enable verbose mode
REM SET SetupEnvVerbose=Yes

REM Inject ANSICON if we're not running inside ConEmu
SET AnsiConPath=C:\Program Files (x86)\Nexiom\Software\Independent\ANSICON\ansicon.exe
IF NOT DEFINED ConEmuANSI (
    IF EXIST "%AnsiConPath%" (
        IF !ANSICON_VER!==^!ANSICON_VER^! "%AnsiConPath%" -p
    )
)
SET AnsiConPath=

REM Because I'm tired of forgetting Cmd is not a *nix shell
DOSKEY clear=cls
DOSKEY ls=dir $*
DOSKEY man=help $*
DOSKEY which=where $*

REM Add alias for Sublime Text
SET SublRegPath=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1
SET SublBinName=sublime_text.exe
REG QUERY "%SublRegPath%" /v InstallLocation > NUL 2>&1
IF NOT ERRORLEVEL 1 (
    FOR /F "tokens=2*" %%a IN ('REG QUERY "%SublRegPath%" /v InstallLocation ^| FINDSTR /R "[a-z]:\\.*\\$"') DO @SET SublDirPath=%%b
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO Couldn't locate Sublime Text install; not adding 'subl' alias.
)
IF DEFINED SublDirPath DOSKEY subl="%SublDirPath%%SublBinName%" $*
FOR /F "delims==" %%i IN ('SET Subl') DO @SET %%i=
