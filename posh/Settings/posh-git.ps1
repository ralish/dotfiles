if (Get-Module posh-git -ListAvailable) {
    Import-Module posh-git

    # Add Git repository status info to our prompt
    Function global:prompt {
        $REALLASTEXITCODE = $LASTEXITCODE

        Write-Host ($pwd.ProviderPath) -NoNewline
        Write-VcsStatus

        $global:LASTEXITCODE = $REALLASTEXITCODE
        return '> '
    }
} else {
    Write-Verbose "Couldn't locate posh-git module; not importing to environment."
}