@ECHO OFF

IF [%DOTFILES%] == [] (
    ECHO The %%DOTFILES%% variable has not been set.
    EXIT /B
)

REG ADD "HKCU\Software\Microsoft\Command Processor" ^
    /v AutoRun ^
    /t REG_EXPAND_SZ ^
    /d "IF NOT DEFINED SetupEnv ""%%DOTFILES%%\cmd\SetupEnv.cmd""" ^
    /f
