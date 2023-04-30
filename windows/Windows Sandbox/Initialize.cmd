@ECHO OFF

@REM Switch to batch file directory
CD /D "%~dp0"

@REM Add Sysinternals to system path
FOR /F "usebackq tokens=2,*" %%A IN (`REG QUERY "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path`) DO SET PATH_MACHINE=%%B
SETX /M PATH "C:\Program Files (x86)\Sysinternals;%PATH_MACHINE%"
