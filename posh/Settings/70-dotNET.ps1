$DotFilesSection = @{
    Type    = 'Settings'
    Name    = '.NET'
    Command = @('dotnet')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Opt-out of telemetry
$env:DOTNET_CLI_TELEMETRY_OPTOUT = 'true'

# How to enable tab completion for the .NET CLI
# https://learn.microsoft.com/en-au/dotnet/core/tools/enable-tab-autocomplete#powershell
Register-ArgumentCompleter -Native -CommandName 'dotnet' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Complete-DotFilesSection
