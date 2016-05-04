# **************************** Profile Configuration ***************************

# Path to our dotfiles directory
# TODO: Determine this dynamically
$DotFilesPath = "$HOME\dotfiles"

# Path where our SSH keys are stored
$SshKeysPath = 'Y:\Secured\SSH Keys'
# Extension of SSH private keys (so we don't import private keys stored in a different format)
$SshKeysExt  = '.opk'

# Path to Dependency Walker (32-bit)
$Dw32Path = 'C:\Program Files (x86)\Nexiom\Software\Independent\Dependency Walker\depends.exe'
# Path to Dependency Walker (64-bit)
$Dw64Path = 'C:\Program Files\Nexiom\Software\Independent\Dependency Walker\depends.exe'

# Path to Sublime Text installation registry key
$SublRegPath = 'HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\Sublime Text 2_is1'

# ******************************************************************************


# Determine the parent directory of our profile script
$ScriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Import all available modules with our custom settings
Get-ChildItem (Join-Path $ScriptPath 'Settings') -File | % { . $_.FullName }

# Load keys into ssh-agent (if we're not using Plink)
if ($env:GIT_SSH -inotmatch 'plink') {
    if (Get-Command ssh-add.exe -ErrorAction SilentlyContinue) {
        if (Test-Path -PathType Container $SshKeysPath) {
            $SshKeys = Get-ChildItem $SshKeysPath | ? { $_.Extension -eq $SshKeysExt }
            if ($SshKeys) {
                $SshKeys | % { ssh-add $_ 2>&1 } | Out-Null
            } else {
                Write-Warning "Couldn't locate any SSH keys to add; looking for extension: $SshKeysExt"
            }
        } else {
            Write-Warning "The provided SSH keys location doesn't exist: $SshKeysPath"
        }
    } else {
        Write-Warning "Couldn't locate ssh-add.exe binary; not adding SSH keys to agent."
    }
}

# Source any function files in our Functions directory
if (Test-Path "$ScriptPath\Functions" -PathType Container) {
    Get-ChildItem "$ScriptPath\Functions" | % { . $_.FullName }
}

# Amend our Path to include our Scripts directory
$env:Path += ";$ScriptPath\Scripts"

# Source our custom aliases & functions
. (Join-Path $ScriptPath 'Aliases.ps1')
. (Join-Path $ScriptPath 'Functions.ps1')

# Clean-up
Remove-Variable ScriptPath
