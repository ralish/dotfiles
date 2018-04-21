# Load SSH keys into ssh-agent if we're not using Plink
if ($env:GIT_SSH -notmatch '\\plink\.exe$') {
    # Path to our SSH keys
    $SshKeysPath = 'Y:\Secured\SSH Keys'
    # SSH keys file extension
    $SshKeysExt  = '.opk'

    if (Get-Command -Name ssh-add -ErrorAction SilentlyContinue) {
        if (Test-Path -Path $SshKeysPath -PathType Container) {
            $SshKeys = Get-ChildItem -Path $SshKeysPath -File | Where-Object { $_.Extension -eq $SshKeysExt }
            if ($SshKeys) {
                $null = $SshKeys | ForEach-Object { ssh-add $_ 2>&1 }
                Remove-Variable -Name SshKeys
            } else {
                Write-Warning -Message ('[dotfiles] No SSH keys found with extension: {0}' -f $SshKeysExt)
            }
        } else {
            Write-Warning -Message ('[dotfiles] The specified SSH keys location does not exist: {0}' -f $SshKeysPath)
        }
    } else {
        Write-Warning -Message '[dotfiles] Not loading SSH keys into ssh-agent as unable to locate ssh-add.'
    }

    Remove-Variable -Name ('SshKeysExt', 'SshKeysPath')
} else {
    Write-Verbose -Message '[dotfiles] Skipping loading SSH keys into ssh-agent as using Plink.'
}
