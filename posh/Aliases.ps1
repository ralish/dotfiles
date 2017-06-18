# **************************** Aliases Configuration ***************************
#
# Path to Dependency Walker (32-bit)
$Dw32Path = "${env:ProgramFiles(x86)}\Nexiom\Software\Independent\Dependency Walker\depends.exe"
# Path to Dependency Walker (64-bit)
$Dw64Path = "$env:ProgramW6432\Nexiom\Software\Independent\Dependency Walker\depends.exe"
#
# Path to Sublime Text 2 installation registry key
$SublRegPath = 'HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1'
#
# ******************************************************************************

# Some useful aliases
Set-Alias -Name gh -Value Get-Help
Set-Alias -Name which -Value Get-Command

# Add alias for Dependency Walker x86
if (Test-Path -Path $Dw32Path -PathType Leaf) {
    Set-Alias -Name depends32 -Value $Dw32Path
} else {
    Write-Verbose -Message 'Unable to locate Dependency Walker x86 at path specified by $Dw32Path.'
}
Remove-Variable -Name Dw32Path

# Add alias for Dependency Walker x64
if (Test-Path -Path $Dw64Path -PathType Leaf) {
    Set-Alias -Name depends64 -Value $Dw64Path
} else {
    Write-Verbose -Message 'Unable to locate Dependency Walker x64 at path specified by $Dw64Path.'
}
Remove-Variable -Name Dw64Path

# Add alias for Sublime Text 2
if (!(Get-Command -Name 'subl.exe' -ErrorAction SilentlyContinue)) {
    $SublBinName = 'sublime_text.exe'
    if (Test-Path -Path $SublRegPath -PathType Container) {
        Set-Alias -Name subl -Value (Join-Path -Path (Get-ItemProperty -Path $SublRegPath).InstallLocation -ChildPath $SublBinName)
    } else {
        Write-Verbose -Message 'Unable to locate Sublime Text installation so not adding alias.'
    }
    Remove-Variable -Name SublBinName
} else {
    Write-Verbose -Message 'Found subl.exe in search path so not adding an alias.'
}
Remove-Variable -Name SublRegPath
