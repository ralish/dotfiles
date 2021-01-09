if ($DotFilesShowScriptEntry) { Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath) }

if (!(Get-Command -Name dotnet -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping .NET Core settings as unable to locate dotnet.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading .NET Core settings ...')

# Opt-out of telemetry
$env:DOTNET_CLI_TELEMETRY_OPTOUT = 'true'

# How to enable TAB completion for the .NET Core CLI
# https://docs.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
