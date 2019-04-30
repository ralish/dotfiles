if (!(Test-IsWindows)) {
    return
}

if ($env:GIT_SSH -match '\\plink\.exe$') {
    Write-Verbose -Message '[dotfiles] Skipping loading SSH keys into ssh-agent as using Plink.'
    return
}

if (!(Get-Command -Name ssh-add -ErrorAction Ignore)) {
    Write-Warning -Message '[dotfiles] Unable to locate ssh-add to load SSH keys into ssh-agent.'
    return
}

# Path to our SSH keys
$SshKeysPath = 'Y:\Secured\SSH Keys'
# SSH keys file extension
$SshKeysExt  = '.opk'

if (Test-Path -Path $SshKeysPath -PathType Container) {
    $SshKeys = Get-ChildItem -Path $SshKeysPath -File | Where-Object { $_.Extension -eq $SshKeysExt }
    if ($SshKeys) {
        Write-Verbose -Message '[dotfiles] Loading SSH keys into ssh-agent ...'
        $null = $SshKeys | ForEach-Object { ssh-add $_ 2>&1 }
        Remove-Variable -Name SshKeys
    } else {
        Write-Warning -Message ('[dotfiles] No SSH keys found with extension: {0}' -f $SshKeysExt)
    }
} else {
    Write-Warning -Message ('[dotfiles] The specified SSH keys location does not exist: {0}' -f $SshKeysPath)
}

Remove-Variable -Name @('SshKeysExt', 'SshKeysPath')
