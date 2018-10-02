# Some useful aliases
Set-Alias -Name cop     -Value Compare-ObjectProperties
Set-Alias -Name gh      -Value Get-Help
Set-Alias -Name gita    -Value Invoke-GitChildDir
Set-Alias -Name which   -Value Get-Command

# Dependency Walker (x86)
$DepWalker32Path = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Nexiom\Software\Independent\Dependency Walker\depends.exe'
if (Test-Path -Path $DepWalker32Path -PathType Leaf) {
    Set-Alias -Name depends32 -Value $DepWalker32Path
} else {
    Write-Verbose -Message '[dotfiles] Unable to locate Dependency Walker (x86) for alias.'
}
Remove-Variable -Name DepWalker32Path

# Dependency Walker (x64)
$DepWalker64Path = Join-Path -Path $env:ProgramW6432 -ChildPath 'Nexiom\Software\Independent\Dependency Walker\depends.exe'
if (Test-Path -Path $DepWalker64Path -PathType Leaf) {
    Set-Alias -Name depends64 -Value $DepWalker64Path
} else {
    Write-Verbose -Message '[dotfiles] Unable to locate Dependency Walker (x64) for alias.'
}
Remove-Variable -Name DepWalker64Path

# Sublime Text 2
$Sublime2RegPath = 'HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1'
if (!(Get-Command -Name subl.exe -ErrorAction Ignore)) {
    if (Test-Path -Path $Sublime2RegPath -PathType Container) {
        Set-Alias -Name subl -Value (Join-Path -Path (Get-ItemProperty -Path $Sublime2RegPath).InstallLocation -ChildPath 'sublime_text.exe')
    } else {
        Write-Verbose -Message '[dotfiles] Unable to locate Sublime Text 2 for alias.'
    }
} else {
    Write-Verbose -Message '[dotfiles] Skipping Sublime Text 2 alias as found subl.exe in PATH.'
}
Remove-Variable -Name Sublime2RegPath
