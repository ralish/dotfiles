if (!(Get-Command -Name dotnet -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping .NET Core settings as unable to locate dotnet.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading .NET Core settings ...')

# Opt-out of telemetry
Set-Item -Path Env:\DOTNET_CLI_TELEMETRY_OPTOUT -Value 'true'

# Command completion for the dotnet CLI
# https://docs.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    Param($CommandName, $WordToComplete, $CursorPosition)
    dotnet complete --position $CursorPosition, "$WordToComplete" | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
