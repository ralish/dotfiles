# Some useful aliases
Set-Alias gh Get-Help
Set-Alias which Get-Command

# Add alias for Sublime Text
$SublRegPath = 'HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1'
$SublBinName = 'sublime_text.exe'
if (Test-Path $SublRegPath) {
    $SublInfo = Get-ItemProperty $SublRegPath
    Set-Alias subl (Join-Path $SublInfo.InstallLocation $SublBinName)
} else {
    Write-Verbose "Couldn't locate Sublime Text install; not adding 'subl' alias."
}
Remove-Variable SublRegPath, SublBinName, SublInfo
