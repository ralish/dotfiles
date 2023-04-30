#NoEnv
#NoTrayIcon
#SingleInstance force
#Warn

SendMode Input
SetTitleMatchMode, 3
SetWorkingDir, %A_ScriptDir%

procName := "ONENOTE.EXE"

; Set cursor to page title for all pages in the current section
!q::
IfWinActive, ahk_exe %ProcName%
{
    Send !{Home}
    Loop, 31 {
        Send ^+T
        Send {Home}
        Send ^{PgDn}
    }
}
