@ECHO OFF
ECHO Making Command Prompt suck slightly less...

REM Uncomment to enable verbose mode
REM SET VERBOSE=YES

REM So that we can safely run via AutoRun
REM Use something like: IF NOT DEFINED SETUPENV Path\To\SetupEnv.Cmd
SET SETUPENV=YES

REM Because I'm tired of forgetting this
DOSKEY ls=dir
DOSKEY man=help
DOSKEY which=where

REM Add alias for Sublime Text
SET SUBLREGPATH=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1
SET SUBLBINNAME=sublime_text.exe
REG QUERY "%SUBLREGPATH%" /v InstallLocation > NUL 2>&1
IF NOT ERRORLEVEL 1 (
    FOR /F "tokens=2*" %%a IN ('REG QUERY "%SUBLREGPATH%" /v InstallLocation ^| FINDSTR /R "[a-z]:\\.*\\$"') DO @SET SUBLDIRPATH=%%b
    DOSKEY subl="%SUBLDIRPATH%%SUBLBINNAME%" $*
) ELSE (
    IF DEFINED VERBOSE ECHO Couldn't locate Sublime Text install; not adding 'subl' alias.
)
FOR /F "delims==" %%i IN ('SET SUBL') DO @SET %%i=
