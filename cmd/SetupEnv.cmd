@ECHO OFF

REM Bail out before doing anything if invoked by MSBuild. All manner of weird
REM stuff may be about to run which might behave unexpectedly with our config.
IF DEFINED VisualStudioVersion EXIT /B

REM Bail out before doing anything if invoked by Cygwin Setup. Weird changes
REM are made to the environment on autorebase which causes DOSKEY to crash.
IF DEFINED CYGWINROOT EXIT /B

REM Bail out before doing anything if invoked by MinGW. There are some cases I
REM don't understand where MinGW causes this script to be executed incorrectly.
IF DEFINED MSYSTEM EXIT /B

REM So that we can safely run via AutoRun without infinite recursion
REM Key Path: HKEY_CURRENT_USER\Software\Microsoft\Command Processor
REM Use something like: IF NOT DEFINED SetupEnv Path\To\SetupEnv.Cmd
SET SetupEnv=Yes

REM Paths to applications we reference later for additional setup
SET SubText2RegPath=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1
IF DEFINED ProgramFiles(x86) (
    SET AnsiConPath="%ProgramFiles(x86)%\ANSICON\ansicon.exe"
    SET DepWalk32Path="%ProgramFiles(x86)%\Dependency Walker\depends.exe"
    SET DepWalk64Path="%ProgramFiles%\Dependency Walker\depends.exe"
) ELSE (
    SET AnsiConPath="%ProgramFiles%\ANSICON\ansicon.exe"
    SET DepWalk32Path="%ProgramFiles%\Dependency Walker\depends.exe"
)

REM Output a message that our configuration is being applied
REM
REM Unfortunately, some apps spawn a cmd instance and then parse the output as
REM a string. The less durable ones will choke if there's any unexpected output
REM (e.g. MySQL Workbench's version check of mysqldump).
REM ECHO.
REM ECHO Making Command Prompt suck slightly less ...

REM Uncomment to enable verbose mode (but note the above)
REM SET SetupEnvVerbose=Yes
IF DEFINED SetupEnvVerbose ECHO.
IF DEFINED SetupEnvVerbose ECHO Configuring Command Processor:

REM Inject Clink for a more pleasant experience
IF EXIST "%CLINK_DIR%" (
    IF DEFINED SetupEnvVerbose ECHO * [Clink] Injecting ...
    IF /I "%PROCESSOR_ARCHITECTURE%" == "x86" (
        "%CLINK_DIR%\clink_x86.exe" inject -q --profile "~\clink"
    ) ELSE IF /I "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
        IF DEFINED PROCESSOR_ARCHITEW6432 (
            "%CLINK_DIR%\clink_x86.exe" inject -q --profile "~\clink"
        ) ELSE (
            "%CLINK_DIR%\clink_x64.exe" inject -q --profile "~\clink"
        )
    ) ELSE (
        IF DEFINED SetupEnvVerbose ECHO * [Clink] Unsupported processor architecture.
    )
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * [Clink] Unable to find at path specified by CLINK_DIR.
)

REM Inject ANSICON if we're not running under ConEmu
IF NOT DEFINED ConEmuANSI (
    IF EXIST %AnsiConPath% (
        IF DEFINED SetupEnvVerbose ECHO * [ANSICON] Injecting ...
        IF !ANSICON_VER! == ^!ANSICON_VER^! %AnsiConPath% -p
    ) ELSE (
        IF DEFINED SetupEnvVerbose ECHO * [ANSICON] Unable to find at path specified by AnsiConPath.
    )
)
SET AnsiConPath=

REM Configure a more informative prompt if we're running under ConEmu
IF DEFINED ConEmuDir (
    IF DEFINED SetupEnvVerbose ECHO * [Prompt] Configuring ...
    IF "%ConEmuIsAdmin%" == "ADMIN" (
        PROMPT $E[m$E[32m$E]9;8;"USERNAME"$E\@$E]9;8;"COMPUTERNAME"$E\$S$E[91m$P$E[90m$G$E[m$S$E]9;12$E\
    ) ELSE (
        PROMPT $E[m$E[32m$E]9;8;"USERNAME"$E\@$E]9;8;"COMPUTERNAME"$E\$S$E[92m$P$E[90m$G$E[m$S$E]9;12$E\
    )
)

REM Because I'm tired of forgetting this is not a *nix shell
IF DEFINED SetupEnvVerbose ECHO * [DOSKEY] Setting macros ...
DOSKEY clear=cls $*
DOSKEY ls=dir $*
DOSKEY man=help $*
DOSKEY which=where $*

REM Add alias for Dependency Walker x86
IF EXIST %DepWalk32Path% (
    IF DEFINED SetupEnvVerbose ECHO * [Dependency Walker x86] Adding alias: depends32
    DOSKEY depends32=%DepWalk32Path% $*
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * [Dependency Walker x86] Couldn't locate at path specified by DepWalk32Path.
)
SET DepWalk32Path=

REM Add alias for Dependency Walker x64
IF EXIST %DepWalk64Path% (
    IF DEFINED SetupEnvVerbose ECHO * [Dependency Walker x64] Adding alias: depends64
    DOSKEY depends64=%DepWalk64Path% $*
) ELSE (
    IF DEFINED SetupEnvVerbose ECHO * [Dependency Walker x64] Couldn't locate at path specified by DepWalk64Path.
)
SET DepWalk64Path=

REM Add alias for Sublime Text 2
WHERE /Q subl.exe
IF ERRORLEVEL 0 (
    IF DEFINED SetupEnvVerbose ECHO * [Sublime Text 2] Skipping as found a Sublime Text 3 installation.
) ELSE (
    SET SubText2BinName=sublime_text.exe
    REG QUERY "%SubText2RegPath%" /v InstallLocation > NUL 2>&1
    IF ERRORLEVEL 1 (
        IF DEFINED SetupEnvVerbose ECHO * [Sublime Text 2] Couldn't locate via path specified by SubText2RegPath.
    ) ELSE (
        IF DEFINED SetupEnvVerbose ECHO * [Sublime Text 2] Adding alias: subl
        FOR /F "tokens=2*" %%a IN ('REG QUERY "%SubText2RegPath%" /v InstallLocation ^| FINDSTR /R "[a-z]:\\.*\\$"') DO @SET SubText2DirPath=%%b
    )
    IF DEFINED SubText2DirPath DOSKEY subl="%SubText2DirPath%%SubText2BinName%" $*
)
FOR /F "delims==" %%i IN ('SET SubText2') DO @SET %%i=

REM Final clean-up
SET SetupEnvVerbose=
