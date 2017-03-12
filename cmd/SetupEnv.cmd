@ECHO OFF

REM Bail out before doing anything if we we appear to be running under
REM an MSBuild process. All manner of weird stuff could be about to run
REM as part of a build which might behave unexpectedly with our config.
IF DEFINED VisualStudioVersion EXIT /B

REM Bail out before doing anything if we were invoked via Cygwin Setup!!
REM Cygwin does some weird things to the environment while performing an
REM autorebase that at a minimum causes DOSKEY to crash (yes, seriously).
IF DEFINED CYGWINROOT EXIT /B

REM Bail out before doing anything if we were invoked from within MinGW!!
REM There are some weird cases I don't yet fully understand where a CMD
REM spawned by MinGW will execute this script in truly bizarre ways...
IF DEFINED MSYSTEM EXIT /B

REM So that we can safely run via AutoRun without infinite recursion
REM Key Path: HKEY_CURRENT_USER\Software\Microsoft\Command Processor
REM Use something like: IF NOT DEFINED SetupEnv Path\To\SetupEnv.Cmd
SET SetupEnv=Yes

REM Various variables that we may need to tweak
SET AnsiConPath=C:\Program Files (x86)\Nexiom\Software\Independent\ANSICON\ansicon.exe
SET DepWalk32Path=C:\Program Files (x86)\Nexiom\Software\Independent\Dependency Walker\depends.exe
SET DepWalk64Path=C:\Program Files\Nexiom\Software\Independent\Dependency Walker\depends.exe
SET SubText2RegPath=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1

REM We used to notify that the Command Prompt sucks slightly less on every
REM execution. Unfortunately, there are some poorly written apps that spawn
REM a cmd.exe instance and then directly parse the output as a string. Some
REM of those will choke if we echo out any additional output like the below.
REM I'm looking at you MySQL Workbench and your version check of mysqldump!!
REM IF DEFINED SetupEnvVerbose ECHO.
REM IF DEFINED SetupEnvVerbose ECHO Making Command Prompt suck slightly less...

REM Uncomment to enable verbose mode
REM SET SetupEnvVerbose=Yes
IF DEFINED SetupEnvVerbose ECHO.
IF DEFINED SetupEnvVerbose ECHO Configuring Command Processor environment:

REM Inject Clink for a more pleasant experience
IF NOT EXIST "%CLINK_DIR%" (
    IF DEFINED SetupEnvVerbose ECHO * Unable to find Clink at path specified by CLINK_DIR.
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * Injecting Clink...
    "%CLINK_DIR%\clink_x64.exe" inject -q --profile "~\clink"
)

REM Inject ANSICON if we're not running under ConEmu
IF NOT DEFINED ConEmuANSI (
    IF NOT EXIST "%AnsiConPath%" (
        IF DEFINED SetupEnvVerbose ECHO * Unable to find ANSICON at path specified by AnsiConPath.
    ) ELSE (
        IF DEFINED SetupEnvVerbose ECHO * Injecting ANSICON...
        IF !ANSICON_VER!==^!ANSICON_VER^! "%AnsiConPath%" -p
    )
)
SET AnsiConPath=

REM Configure a more informative prompt if we're running under ConEmu
IF DEFINED ConEmuDir (
    IF DEFINED SetupEnvVerbose ECHO * Configuring the prompt...
    IF "%ConEmuIsAdmin%" == "ADMIN" (
        PROMPT $E[m$E[32m$E]9;8;"USERNAME"$E\@$E]9;8;"COMPUTERNAME"$E\$S$E[91m$P$E[90m$G$E[m$S$E]9;12$E\
    ) ELSE (
        PROMPT $E[m$E[32m$E]9;8;"USERNAME"$E\@$E]9;8;"COMPUTERNAME"$E\$S$E[92m$P$E[90m$G$E[m$S$E]9;12$E\
    )
)

REM Because I'm tired of forgetting Cmd is not a *nix shell
IF DEFINED SetupEnvVerbose ECHO * Setting DOSKEY macros...
DOSKEY clear=cls
DOSKEY ls=dir $*
DOSKEY man=help $*
DOSKEY which=where $*

REM Add alias for Dependency Walker x86
IF NOT EXIST "%DepWalk32Path%" (
    IF DEFINED SetupEnvVerbose ECHO * Couldn't locate Dependency Walker x86 at path specified by DepWalk32Path.
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * Adding Dependency Walker x86 alias: depends32
    DOSKEY depends32="%DepWalk32Path%" $*
)
SET DepWalk32Path=

REM Add alias for Dependency Walker x64
IF NOT EXIST "%DepWalk64Path%" (
    IF DEFINED SetupEnvVerbose ECHO * Couldn't locate Dependency Walker x64 at path specified by DepWalk64Path.
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * Adding Dependency Walker x64 alias: depends64
    DOSKEY depends64="%DepWalk64Path%" $*
)
SET DepWalk64Path=

REM Add alias for Sublime Text 2
WHERE /Q subl.exe
IF ERRORLEVEL 0 (
    IF DEFINED SetupEnvVerbose ECHO * Found Sublime Text 3 so not adding an alias.
) ELSE (
    SET SubText2BinName=sublime_text.exe
    REG QUERY "%SubText2RegPath%" /v InstallLocation > NUL 2>&1
    IF ERRORLEVEL 1 (
        IF DEFINED SetupEnvVerbose ECHO * Couldn't locate Sublime Text 2 via path specified by SubText2RegPath.
    ) ELSE (
        IF DEFINED SetupEnvVerbose ECHO * Adding Sublime Text 2 alias: subl
        FOR /F "tokens=2*" %%a IN ('REG QUERY "%SubText2RegPath%" /v InstallLocation ^| FINDSTR /R "[a-z]:\\.*\\$"') DO @SET SubText2DirPath=%%b
    )
    IF DEFINED SubText2DirPath DOSKEY subl="%SubText2DirPath%%SubText2BinName%" $*
    FOR /F "delims==" %%i IN ('SET SubText2') DO @SET %%i=
)

REM Remove the Verbose variable if it was ever set
SET SetupEnvVerbose=
