@ECHO OFF

REM ###########################################################################
REM ###                         Pre-init Checks                             ###
REM ###########################################################################

REM The intent here is to avoid running our environment setup script when CMD
REM is not being launched interactively. There's a couple of reasons why this
REM is desirable. One is potentially causing issues with automated invocations
REM due to the environment changes we make. Another is performance, as this
REM script may launch a dozen or more processes throughout its processing.

REM Bail-out: MSBuild & Visual Studio
REM Performance impact & may cause unexpected behaviour
IF DEFINED MSBuildExtensionsPath EXIT /B
IF DEFINED VisualStudioVersion EXIT /B

REM Bail-out: MinGW & MSYS
REM In some scenarios our script doesn't execute correctly
IF DEFINED MSYSTEM EXIT /B

REM Bail-out: Cygwin Setup
REM Environment changes on autorebase cause DOSKEY to crash
IF DEFINED CYGWINROOT EXIT /B

REM Remove any double quotes from the command line that was passed to CMD, as
REM they are likely to cause problems with subsequent string comparisons.
REM
REM The assignment of CMDCMDLINE to _CMDCMDLINE before then assigning the
REM result of the string substitution is deliberate. For example, running:
REM
REM SET _CMDCMDLINE=%%CMDCMDLINE:"=%%
REM
REM Will result in *both* CMDCMDLINE and _CMDCMDLINE now having the result of
REM the string substitution, despite there being no assignment to CMDCMDLINE.
REM This is in contrast to how every other variable behaves.
SET _CMDCMDLINE=%CMDCMDLINE%
SET _CMDCMDLINE=%_CMDCMDLINE:"=%

REM Also remove any spaces for the same reason of causing problems with the
REM string comparisons. This also has the benefit of removing trailing spaces.
SET _CMDCMDLINE=%_CMDCMDLINE: =%

REM The goal here is to only proceed if the command line provided to CMD ends
REM with the CMD executable itself. This implies it's probably being called for
REM interactive usage, rather than to run a batch script or program.
REM
REM FindStr would be better here as it can do a regular expression test, but it
REM means launching a separate process, which we're trying to avoid.
IF /I [%_CMDCMDLINE%] == [cmd] GOTO Init
IF /I [%_CMDCMDLINE%] == [cmd.exe] GOTO Init
IF /I [%_CMDCMDLINE:~-12%] == [System32\cmd] GOTO Init
IF /I [%_CMDCMDLINE:~-16%] == [System32\cmd.exe] GOTO Init
SET _CMDCMDLINE=
EXIT /B

:Init
REM ###########################################################################
REM ###                         Initialisation                              ###
REM ###########################################################################

REM So that we can safely run via AutoRun without infinite recursion
REM Key Path: HKEY_CURRENT_USER\Software\Microsoft\Command Processor
REM Use something like: IF NOT DEFINED SetupEnv Path\To\SetupEnv.cmd
SET SetupEnv=Yes

REM Uncomment to enable verbose mode
REM
REM This should only be used for debugging as it can interfere with programs
REM which spawn a CMD instance and parse the output.
REM SET SetupEnvVerbose=Yes
IF DEFINED SetupEnvVerbose ECHO.
IF DEFINED SetupEnvVerbose ECHO Configuring Command Processor:

REM Switch to the user's profile directory if the current path is the Windows
REM System32 directory. This probably means we launched as an elevated process.
IF /I "%CD%" == "%SystemRoot%\System32" (
    CD /D "%USERPROFILE%"
)

REM ###########################################################################
REM ###                              Clink                                  ###
REM ###########################################################################

WHERE /Q "clink.cmd"
IF ERRORLEVEL 0 (
    REM Found in %PATH% (likely installed via Scoop or similar)
    SET ClinkPath="clink.cmd"
    GOTO ClinkRun
)
IF EXIST "%CLINK_DIR%" (
    REM Found via %CLINK_DIR% (set via Clink's own installer)
    SET ClinkPath="%CLINK_DIR%\clink.bat"
    GOTO ClinkRun
)
GOTO ClinkSkip

:ClinkRun
IF DEFINED SetupEnvVerbose ECHO * [Clink] Injecting ...
CALL "%ClinkPath%" inject --autorun --profile ~\clink
SET ClinkPath=
GOTO ClinkEnd

:ClinkSkip
IF DEFINED SetupEnvVerbose ECHO * [Clink] Not found.

:ClinkEnd

REM ###########################################################################
REM ###                             ANSICON                                 ###
REM ###########################################################################

REM ConEmu provides its own ANSI support
IF DEFINED ConEmuANSI GOTO AnsiConEnd

WHERE /Q "ansicon.exe"
IF ERRORLEVEL 1 (
    GOTO AnsiConSkip
)

IF DEFINED SetupEnvVerbose ECHO * [ANSICON] Injecting ...
IF !ANSICON_VER! == ^!ANSICON_VER^! "ansicon.exe" -p
GOTO AnsiConEnd

:AnsiConSkip
IF DEFINED SetupEnvVerbose ECHO * [ANSICON] Not found.

:AnsiConEnd

REM ###########################################################################
REM ###                             ConEmu                                  ###
REM ###########################################################################

REM Check we're running under ConEmu
IF NOT DEFINED ConEmuDir GOTO ConEmuEnd

REM Setup a more informative prompt
IF DEFINED SetupEnvVerbose ECHO * [ConEmu] Configuring prompt ...
IF "%ConEmuIsAdmin%" == "ADMIN" (
    PROMPT $E[m$E[32m$E]9;8;"USERNAME"$E\@$E]9;8;"COMPUTERNAME"$E\$S$E[91m$P$E[90m$G$E[m$S$E]9;12$E\
) ELSE (
    PROMPT $E[m$E[32m$E]9;8;"USERNAME"$E\@$E]9;8;"COMPUTERNAME"$E\$S$E[92m$P$E[90m$G$E[m$S$E]9;12$E\
)

:ConEmuEnd

REM ###########################################################################
REM ###                             DOSKEY                                  ###
REM ###########################################################################

WHERE /Q "doskey.exe"
IF ERRORLEVEL 1 (
    GOTO DosKeySkip
)

REM Because I'm tired of forgetting this is not a *nix shell
IF DEFINED SetupEnvVerbose ECHO * [DOSKEY] Configuring ...
DOSKEY clear=cls $*
DOSKEY ls=dir $*
DOSKEY man=help $*
DOSKEY which=where $*
GOTO DosKeyEnd

:DosKeySkip
IF DEFINED SetupEnvVerbose ECHO * [DOSKEY] Not found.

:DosKeyEnd

REM ###########################################################################
REM ###                               End                                   ###
REM ###########################################################################

REM Remove script variables
SET _CMDCMDLINE=
SET SetupEnvVerbose=
