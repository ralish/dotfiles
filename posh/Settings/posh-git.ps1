if (Get-Module -Name posh-git -ListAvailable) {
    Import-Module -Name posh-git
} else {
    Write-Verbose -Message '[dotfiles] Skipping posh-git settings as module not found.'
}
