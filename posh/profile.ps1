# Load posh-git if we're running PoSh >= 2.0
$PoshGitPath = (Join-Path (Split-Path $PROFILE) 'Modules\posh-git\profile.ps1')
if ($PSVersionTable.PSVersion.Major -ge 2) {
    if (Test-Path $PoshGitPath -PathType Leaf) {
        . $PoshGitPath
    } else {
        Write-Verbose "Couldn't locate posh-git module; not importing to environment."
    }
}

# Source our custom functions
. (Join-Path $PSScriptRoot 'Functions.ps1')

# Some useful aliases
Set-Alias which Get-Command

# PowerShell paging sucks so hard but this helps a little
if (Test-Path Function:\more) {
    Remove-Item Function:\more
}
Set-Alias more 'Out-Host -paging'

# Add alias for Sublime Text
$SublRegPath = 'HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1'
$SublBinName = 'sublime_text.exe'
if (Test-Path $SublRegPath) {
    $SublInfo = Get-ItemProperty $SublRegPath
    Set-Alias subl (Join-Path $SublInfo.InstallLocation $SublBinName)
} else {
    Write-Verbose "Couldn't locate Sublime Text install; not adding 'subl' alias."
}

# Add SSH keys to ssh-agent
$SshKeysPath = 'Y:\Secured\SSH Keys\*.opk'
if (Get-Command ssh-add.exe) {
    Get-ChildItem $SshKeysPath | % { ssh-add $_ 2>&1 } | Out-Null
} else {
    Write-Verbose "Couldn't locate ssh-add.exe binary; not adding SSH keys to ssh-agent."
}
