if (Get-Module -Name posh-git -ListAvailable) {
    Import-Module -Name posh-git

    # Add Git repository status info to our prompt
    Function global:prompt {
        $REALLASTEXITCODE = $LASTEXITCODE

        Write-Host -NoNewline -Object ($pwd.ProviderPath)
        Write-VcsStatus

        $global:LASTEXITCODE = $REALLASTEXITCODE
        return '> '
    }
} else {
    Write-Verbose -Message 'Unable to locate posh-git module.'
}
