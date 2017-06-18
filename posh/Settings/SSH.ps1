# ****************************** SSH Configuration *****************************
#
# Path where our SSH keys are stored
$SshKeysPath = 'Y:\Secured\SSH Keys'
# Extension of SSH private keys (so we don't import keys in a different format)
$SshKeysExt  = '.opk'
#
# ******************************************************************************


# Load keys into ssh-agent (if we're not using Plink)
if ($env:GIT_SSH -notmatch '\\plink\.exe$') {
    if (Get-Command -Name ssh-add.exe -ErrorAction SilentlyContinue) {
        if (Test-Path -Path $SshKeysPath -PathType Container) {
            $SshKeys = Get-ChildItem -Path $SshKeysPath -File | Where-Object { $_.Extension -eq $SshKeysExt }
            if ($SshKeys) {
                $null = $SshKeys | ForEach-Object { ssh-add $_ 2>&1 }
                Remove-Variable -Name SshKeys
            } else {
                Write-Warning -Message ('No SSH keys found with expected extension: {0}' -f $SshKeysExt)
            }
        } else {
            Write-Warning -Message ('The SSH keys location does not exist: {0}' -f $SshKeysPath)
        }
    } else {
        Write-Warning -Message 'Not adding SSH keys to ssh-agent as unable to locate ssh-add.'
    }
} else {
    Write-Verbose -Message 'Not adding SSH keys as GIT_SSH is configured to use plink.'
}
Remove-Variable -Name ('SshKeysExt', 'SshKeysPath')
