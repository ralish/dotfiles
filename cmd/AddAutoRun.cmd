@ECHO OFF

@REM Using the AutoRun setting is almost always more trouble than it's worth.
@REM Doing anything non-trivial will incur a performance penalty on account of
@REM the sheer number of things that spawn a CMD process, but the bigger issue
@REM is the negative interactions it can have with other programs due to the
@REM changes it explicitly or implicitly makes in the CMD environment. Catching
@REM all these cases is effectively impossible, and they're often not obvious.

IF [%DOTFILES%] == [] (
    ECHO The %%DOTFILES%% variable has not been set.
    EXIT /B
)

REG ADD "HKCU\Software\Microsoft\Command Processor" ^
    /v AutoRun ^
    /t REG_EXPAND_SZ ^
    /d """%%DOTFILES%%\cmd\SetupEnv.cmd""" ^
    /f
