$DotFilesSection = @{
    Type    = 'Settings'
    Name    = '.NET Core'
    Command = @('dotnet')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Opt-out of telemetry
$env:DOTNET_CLI_TELEMETRY_OPTOUT = 'true'

# How to enable TAB completion for the .NET Core CLI
# https://docs.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete
Register-ArgumentCompleter -Native -CommandName 'dotnet' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Complete-DotFilesSection
