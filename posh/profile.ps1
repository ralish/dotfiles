# Load PSReadLine if we're running PoSh >= 3.0
if ($PSVersionTable.PSVersion.Major -ge 3) {
    if ((Get-Module PSReadLine -ListAvailable) -and ($Host.Name -eq 'ConsoleHost')) {
        Import-Module PSReadLine
    } else {
        Write-Verbose "Couldn't locate PSReadLine module; not importing to environment."
    }
}

# Load posh-git if we're running PoSh >= 2.0
if ($PSVersionTable.PSVersion.Major -ge 2) {
    if (Get-Module posh-git -ListAvailable) {
        Import-Module posh-git
        Enable-GitColors
        Start-SshAgent -Quiet
    } else {
        Write-Verbose "Couldn't locate posh-git module; not importing to environment."
    }
}

# Add SSH keys to ssh-agent
$SshKeysPath = 'Y:\Secured\SSH Keys\*.opk'
if (Get-Command ssh-add.exe) {
    Get-ChildItem $SshKeysPath | % { ssh-add $_ 2>&1 } | Out-Null
} else {
    Write-Verbose "Couldn't locate ssh-add.exe binary; not adding SSH keys to ssh-agent."
}

# Source our custom aliases & functions
. (Join-Path $PSScriptRoot 'Aliases.ps1')
. (Join-Path $PSScriptRoot 'Functions.ps1')
