if (!(Get-Module -Name oh-my-posh -ListAvailable)) {
    Write-Verbose -Message '[dotfiles] Skipping oh-my-posh settings as module not found.'
    return
}

Write-Verbose -Message '[dotfiles] Loading oh-my-posh settings ...'

# Set console theme
Set-Theme -Name Agnoster
