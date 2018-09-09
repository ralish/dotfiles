if (Get-Command -Name dotnet -ErrorAction Ignore) {
    Write-Verbose -Message '[dotfiles] Loading .NET Core settings ...'

    # Opt-out of telemetry
    Set-Item -Path Env:\DOTNET_CLI_TELEMETRY_OPTOUT -Value 'true'
} else {
    Write-Verbose -Message '[dotfiles] Skipping .NET Core settings as unable to locate dotnet.'
}
