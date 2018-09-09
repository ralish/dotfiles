if (Get-Module -Name posh-git -ListAvailable) {
    Write-Verbose -Message '[dotfiles] Loading posh-git settings ...'
    Import-Module -Name posh-git

    # Abbreviate home directory path with tilde
    $GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true

    # Prefix prompt with username and hostname
    $GitPromptSettings.DefaultPromptPrefix.Text = '{0}@{1} ' -f $env:USERNAME, $env:COMPUTERNAME
} else {
    Write-Verbose -Message '[dotfiles] Skipping posh-git settings as module not found.'
}
