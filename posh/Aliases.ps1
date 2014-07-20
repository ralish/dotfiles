# Various variables that we may need to tweak
$Dw32Path = 'C:\Program Files (x86)\Nexiom\Software\Independent\Dependency Walker\depends.exe'
$Dw64Path = 'C:\Program Files\Nexiom\Software\Independent\Dependency Walker\depends.exe'
$SublRegPath = 'HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1'

# Some useful aliases
Set-Alias gh Get-Help
Set-Alias which Get-Command

# Add alias for Dependency Walker x86
if (Test-Path $Dw32Path -PathType Leaf) {
    Set-Alias depends32 $Dw32Path
} else {
    Write-Verbose "Couldn't locate Dependency Walker x86 at path specified by Dw32Path."
}
Remove-Variable Dw32Path

# Add alias for Dependency Walker x64
if (Test-Path $Dw64Path -PathType Leaf) {
    Set-Alias depends64 $Dw64Path
} else {
    Write-Verbose "Couldn't locate Dependency Walker x64 at path specified by Dw64Path."
}
Remove-Variable Dw64Path

# Add alias for Sublime Text
$SublBinName = 'sublime_text.exe'
if (Test-Path $SublRegPath -PathType Container) {
    $SublInfo = Get-ItemProperty $SublRegPath
    Set-Alias subl (Join-Path $SublInfo.InstallLocation $SublBinName)
} else {
    Write-Verbose "Couldn't locate Sublime Text installation so not adding 'subl' alias."
}
Remove-Variable SublRegPath, SublBinName, SublInfo
