@ECHO OFF
ECHO.
ECHO Making Command Prompt suck slightly less...

REM Various variables that we may need to tweak
SET AnsiConPath=C:\Program Files (x86)\Nexiom\Software\Independent\ANSICON\ansicon.exe
SET ClinkPath=C:\Program Files (x86)\Nexiom\Software\Independent\clink\0.4.1\clink_x64.exe
SET Dw32Path=C:\Program Files (x86)\Nexiom\Software\Independent\Dependency Walker\depends.exe
SET Dw64Path=C:\Program Files\Nexiom\Software\Independent\Dependency Walker\depends.exe
SET SublRegPath=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1

REM So that we can safely run via AutoRun without infinite recursion
REM Key Path: HKEY_CURRENT_USER\Software\Microsoft\Command Processor
REM Use something like: IF NOT DEFINED SetupEnv Path\To\SetupEnv.Cmd
SET SetupEnv=Yes

REM Uncomment to enable verbose mode
REM SET SetupEnvVerbose=Yes

REM Bail out before doing anything if we were invoked via Cygwin Setup!!
REM Cygwin does some weird things to the environment while performing an
REM autorebase that at a minimum causes DOSKEY to crash (yes, seriously).
IF DEFINED CYGWINROOT EXIT /B

REM Inject Clink for a more pleasant experience
IF NOT EXIST "%ClinkPath%" (
    IF DEFINED SetupEnvVerbose ECHO * Unable to find Clink at path specified by ClinkPath.
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * Injecting Clink into Command Processor...
    "%ClinkPath%" inject -q --profile "~\clink"
)
SET ClinkPath=

REM Inject ANSICON if we're not running inside ConEmu
IF DEFINED ConEmuANSI (
    IF DEFINED SetupEnvVerbose ECHO * Detected we're running in ConEmu so not injecting ANSICON.
) ELSE (
    IF NOT EXIST "%AnsiConPath%" (
        IF DEFINED SetupEnvVerbose ECHO * Unable to find ANSICON at path specified by AnsiConPath.
    ) ELSE (
        IF DEFINED SetupEnvVerbose ECHO * Injecting ANSICON into Command Processor...
        IF !ANSICON_VER!==^!ANSICON_VER^! "%AnsiConPath%" -p
    )
)
SET AnsiConPath=

REM Because I'm tired of forgetting Cmd is not a *nix shell
IF DEFINED SetupEnvVerbose ECHO * Setting DOSKEY macros...
DOSKEY clear=cls
DOSKEY ls=dir $*
DOSKEY man=help $*
DOSKEY which=where $*

REM Add alias for Dependency Walker x86
IF NOT EXIST "%Dw32Path%" (
    IF DEFINED SetupEnvVerbose ECHO * Couldn't locate Dependency Walker x86 at path specified by Dw32Path.
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * Setting Dependency Walker x86 'depends32' alias...
    DOSKEY depends32="%Dw32Path%" $*
)
SET Dw32Path=

REM Add alias for Dependency Walker x64
IF NOT EXIST "%Dw64Path%" (
    IF DEFINED SetupEnvVerbose ECHO * Couldn't locate Dependency Walker x64 at path specified by Dw64Path.
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * Setting Dependency Walker x64 'depends64' alias...
    DOSKEY depends64="%Dw64Path%" $*
)
SET Dw64Path=

REM Add alias for Sublime Text
SET SublBinName=sublime_text.exe
REG QUERY "%SublRegPath%" /v InstallLocation > NUL 2>&1
IF ERRORLEVEL 1 (
    IF DEFINED SetupEnvVerbose ECHO * Couldn't locate Sublime Text installation so not adding 'subl' alias.
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * Setting Sublime Text 'subl' alias...
    FOR /F "tokens=2*" %%a IN ('REG QUERY "%SublRegPath%" /v InstallLocation ^| FINDSTR /R "[a-z]:\\.*\\$"') DO @SET SublDirPath=%%b
)
IF DEFINED SublDirPath DOSKEY subl="%SublDirPath%%SublBinName%" $*
FOR /F "delims==" %%i IN ('SET Subl') DO @SET %%i=

REM Remove the Verbose variable if it was ever set
SET SetupEnvVerbose=
