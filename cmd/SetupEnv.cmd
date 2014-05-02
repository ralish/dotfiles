@ECHO OFF
ECHO Making Command Prompt suck slightly less...

REM So that we can safely run via AutoRun without infinite recursion
REM Key Path: HKEY_CURRENT_USER\Software\Microsoft\Command Processor
REM Use something like: IF NOT DEFINED SetupEnv Path\To\SetupEnv.Cmd
SET SetupEnv=Yes

REM Uncomment to enable verbose mode
REM SET SetupEnvVerbose=Yes

REM Inject ANSICON if we're not running inside ConEmu
SET AnsiConPath=C:\Program Files (x86)\Nexiom\Software\Independent\ANSICON\ansicon.exe
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

REM Add alias for Sublime Text
SET SublRegPath=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1
SET SublBinName=sublime_text.exe
REG QUERY "%SublRegPath%" /v InstallLocation > NUL 2>&1
IF ERRORLEVEL 1 (
    IF DEFINED SetupEnvVerbose ECHO * Couldn't locate Sublime Text installation so not adding 'subl' alias.
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * Setting Sublime Text 'subl' alias...
    FOR /F "tokens=2*" %%a IN ('REG QUERY "%SublRegPath%" /v InstallLocation ^| FINDSTR /R "[a-z]:\\.*\\$"') DO @SET SublDirPath=%%b
    DOSKEY subl="!SublDirPath!%SublBinName%" $*
)
FOR /F "delims==" %%i IN ('SET Subl') DO @SET %%i=

REM Remove the Verbose variable if it was ever set
SET SetupEnvVerbose=
