if (Get-Command -Name dotnet.exe -ErrorAction Ignore) {
    # Opt-out of telemetry
    Set-Item -Path Env:\DOTNET_CLI_TELEMETRY_OPTOUT -Value 'true'
}
