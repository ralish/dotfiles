@ECHO OFF

@REM ##########################################################################
@REM ###                        Initialisation                              ###
@REM ##########################################################################

@REM Uncomment to enable verbose mode
@REM SET SetupEnvVerbose=Yes
IF DEFINED SetupEnvVerbose ECHO.
IF DEFINED SetupEnvVerbose ECHO Configuring Command Processor:

@REM Switch to the user's profile directory if the current path is the Windows
@REM System32 directory. This likely means we launched as an elevated process.
IF /I "%CD%" == "%SystemRoot%\System32" (
    CD /D "%USERPROFILE%"
)

@REM ##########################################################################
@REM ###                             Clink                                  ###
@REM ##########################################################################

WHERE /Q "clink.cmd"
IF NOT ERRORLEVEL 1 (
    @REM Found in %%PATH%% (likely installed via Scoop or similar)
    SET ClinkPath="clink.cmd"
    GOTO ClinkRun
)
IF EXIST "%CLINK_DIR%" (
    @REM Found via %%CLINK_DIR%% (set via Clink's own installer)
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

@REM ##########################################################################
@REM ###                            ANSICON                                 ###
@REM ##########################################################################

@REM ConEmu provides its own ANSI support
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

@REM ##########################################################################
@REM ###                            ConEmu                                  ###
@REM ##########################################################################

@REM Check we're running under ConEmu
IF NOT DEFINED ConEmuDir GOTO ConEmuEnd

@REM Setup a more informative prompt
IF DEFINED SetupEnvVerbose ECHO * [ConEmu] Configuring prompt ...
IF "%ConEmuIsAdmin%" == "ADMIN" (
    PROMPT $E[m$E[32m$E]9;8;"USERNAME"$E\@$E]9;8;"COMPUTERNAME"$E\$S$E[91m$P$E[90m$G$E[m$S$E]9;12$E\
) ELSE (
    PROMPT $E[m$E[32m$E]9;8;"USERNAME"$E\@$E]9;8;"COMPUTERNAME"$E\$S$E[92m$P$E[90m$G$E[m$S$E]9;12$E\
)

:ConEmuEnd

@REM ##########################################################################
@REM ###                        Windows Terminal                            ###
@REM ##########################################################################

@REM Shell Integration: Command Prompt
@REM https://learn.microsoft.com/en-au/windows/terminal/tutorials/shell-integration#command-prompt

@REM Check we're running under Windows Terminal
IF NOT DEFINED WT_SESSION GOTO WinTermEnd

@REM Setup a more informative prompt
IF DEFINED SetupEnvVerbose ECHO * [Windows Terminal] Configuring prompt ...
@REM OSC FinalTerm ; CmdEnd ST
@REM OSC FinalTerm ; PromptStart ST
@REM OSC ConEmu ; CurrentDir ; <Cwd> ST
@REM <Prompt>
@REM OSC FinalTerm ; CmdStart ST
PROMPT $e]133;D$e\$e]133;A$e\$e]9;9;$P$e\$P$G$e]133;B$e\

:WinTermEnd

@REM ##########################################################################
@REM ###                            DOSKEY                                  ###
@REM ##########################################################################

WHERE /Q "doskey.exe"
IF ERRORLEVEL 1 (
    GOTO DosKeySkip
)

@REM Because I'm tired of forgetting this is not a *nix shell
IF DEFINED SetupEnvVerbose ECHO * [DOSKEY] Configuring ...
DOSKEY clear=cls $*
DOSKEY ls=dir $*
DOSKEY man=help $*
DOSKEY which=where $*
GOTO DosKeyEnd

:DosKeySkip
IF DEFINED SetupEnvVerbose ECHO * [DOSKEY] Not found.

:DosKeyEnd

@REM ##########################################################################
@REM ###                              End                                   ###
@REM ##########################################################################

@REM Remove script variables
SET SetupEnvVerbose=
