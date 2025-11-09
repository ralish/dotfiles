@ECHO OFF

@REM ##########################################################################
@REM ###                        Initialisation                              ###
@REM ##########################################################################

@REM Uncomment to enable verbose mode
@REM SET SetupEnvVerbose=Yes
IF DEFINED SetupEnvVerbose (
    ECHO.
    ECHO Configuring Command Processor:
)

@REM If Command Processor is launched elevated the current working directory
@REM will initially be the Windows `System32` directory. In that case, change
@REM to our user profile directory, which is where we most likely want to be.
IF /I "%CD%" == "%SystemRoot%\System32" CD /D "%USERPROFILE%"

@REM ##########################################################################
@REM ###                       Windows Terminal                             ###
@REM ##########################################################################

@REM Shell Integration: Command Prompt
@REM https://learn.microsoft.com/en-au/windows/terminal/tutorials/shell-integration#command-prompt

:WinTermDetect
IF NOT DEFINED WT_SESSION GOTO WinTermSkip

:WinTermFound
SET HasWinTerm=Yes
IF DEFINED SetupEnvVerbose ECHO * [Windows Terminal] Detected.
GOTO :ClinkDetect

:WinTermSkip
SET HasWinTerm=
IF DEFINED SetupEnvVerbose ECHO * [Windows Terminal] Not found.

@REM ##########################################################################
@REM ###                            ConEmu                                  ###
@REM ##########################################################################

@REM Configuring Cmd Prompt
@REM https://conemu.github.io/en/CmdPrompt.html

:ConEmuDetect
IF NOT DEFINED ConEmuDir GOTO ConEmuSkip

:ConEmuFound
SET HasConEmu=Yes
IF DEFINED SetupEnvVerbose ECHO * [ConEmu] Detected.
GOTO :ClinkDetect

:ConEmuSkip
SET HasConEmu=
IF DEFINED SetupEnvVerbose ECHO * [ConEmu] Not found.

@REM ##########################################################################
@REM ###                            ANSICON                                 ###
@REM ##########################################################################

:AnsiConDetect
WHERE /Q "ansicon.exe"
IF ERRORLEVEL 1 GOTO AnsiConSkip

:AnsiConFound
SET HasAnsiCon=Yes
IF DEFINED SetupEnvVerbose ECHO * [ANSICON] Injecting ...
IF !ANSICON_VER! == ^!ANSICON_VER^! "ansicon.exe" -p
GOTO ClinkDetect

:AnsiConSkip
SET HasAnsiCon=
IF DEFINED SetupEnvVerbose ECHO * [ANSICON] Not found.

@REM ##########################################################################
@REM ###                             Clink                                  ###
@REM ##########################################################################

:ClinkDetect
WHERE /Q "clink.cmd"
IF NOT ERRORLEVEL 1 (
    @REM Found in %%PATH%% (likely installed via Scoop or similar)
    SET ClinkPath="clink.cmd"
    GOTO ClinkFound
)
IF EXIST "%CLINK_DIR%" (
    @REM Found via %%CLINK_DIR%% (set via Clink's own installer)
    SET ClinkPath="%CLINK_DIR%\clink.bat"
    GOTO ClinkFound
)
GOTO ClinkSkip

:ClinkFound
SET HasClink=Yes
IF DEFINED SetupEnvVerbose ECHO * [Clink] Injecting ...
CALL "%ClinkPath%" inject --autorun --profile ~\clink
SET ClinkPath=
GOTO PromptSetup

:ClinkSkip
SET HasClink=
IF DEFINED SetupEnvVerbose ECHO * [Clink] Not found.

@REM ##########################################################################
@REM ###                     Prompt customisation                           ###
@REM ##########################################################################

:PromptSetup
SET CustomPrompt=
IF DEFINED SetupEnvVerbose ECHO * [Prompt] Configuring ...
IF DEFINED HasWinTerm GOTO :PromptStartWinTerm
IF DEFINED HasConEmu GOTO :PromptAnsi
IF DEFINED HasAnsiCon GOTO :PromptAnsi
IF DEFINED HasClink GOTO :PromptAnsi

:PromptBasic
@REM Setup basic prompt
@REM $P (Current drive and path)
@REM $G$S ("> ")
SET CustomPrompt=$P$G$S
GOTO PromptApply

:PromptStartWinTerm
@REM Mark end of last command and start of prompt
@REM Applies to: Windows Terminal
@REM
@REM The OSC code to pass the current working directory to the terminal was
@REM initially introduced by ConEmu and is also supported by Windows Terminal.
@REM We only apply it on Windows Terminal as modern ConEmu releases provide
@REM this support through the ConEmuHk library which is injected into CMD.
@REM
@REM OSC FinalTerm ; CmdEnd ST
@REM OSC FinalTerm ; PromptStart ST
@REM OSC ConEmu ; CurrentDir ; "<Cwd>" ST
SET CustomPrompt=$E]133;D$E\$E]133;A$E\$E]9;9;$P$E\

:PromptAnsi
@REM Setup coloured prompt
@REM Applies to: ANSICON, Clink, ConEmu, and Windows Terminal
@REM
@REM SGR ResetAttributes
@REM SGR SetBrightForegroundColour 2
@REM $P (Current drive and path)
@REM SGR SetBrightForegroundColour 0
@REM $G (">")
@REM SGR ResetAttributes
@REM $S (" ")
SET CustomPrompt=%CustomPrompt%$E[m$E[92m$P$E[90m$G$E[m$S
IF DEFINED HasWinTerm GOTO PromptEndWinTerm
IF DEFINED HasConEmu GOTO PromptEndConEmu
GOTO PromptApply

:PromptEndWinTerm
@REM Mark end of prompt
@REM Applies to: Windows Terminal
@REM
@REM OSC FinalTerm ; CmdStart ST
SET CustomPrompt=%CustomPrompt%$E]133;B$E\
GOTO PromptApply

:PromptEndConEmu
@REM Mark start of input
@REM Applies to: ConEmu
@REM
@REM OSC ConEmu ; PromptStart ST
SET CustomPrompt=%CustomPrompt%$E]9;12$E\

:PromptApply
PROMPT %CustomPrompt%
SET CustomPrompt=

@REM ##########################################################################
@REM ###                            DOSKEY                                  ###
@REM ##########################################################################

:DosKeyDetect
WHERE /Q "doskey.exe"
IF ERRORLEVEL 1 GOTO DosKeySkip

:DosKeySetup
IF DEFINED SetupEnvVerbose ECHO * [DOSKEY] Configuring ...
DOSKEY clear=cls $*
DOSKEY ls=dir $*
DOSKEY man=help $*
DOSKEY which=where $*
GOTO Cleanup

:DosKeySkip
IF DEFINED SetupEnvVerbose ECHO * [DOSKEY] Not found.

@REM ##########################################################################
@REM ###                           Clean-up                                 ###
@REM ##########################################################################

:Cleanup
SET HasAnsiCon=
SET HasClink=
SET HasConEmu=
SET HasWinTerm=
SET SetupEnvVerbose=
