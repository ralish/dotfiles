# .NET CLI
# https://learn.microsoft.com/en-au/dotnet/core/tools/
# https://github.com/dotnet/sdk

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = '.NET CLI'
    Command = 'dotnet'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Disable telemetry
$Env:DOTNET_CLI_TELEMETRY_OPTOUT = 'true'

# How to enable tab completion for the .NET CLI
# https://learn.microsoft.com/en-au/dotnet/core/tools/enable-tab-autocomplete
Write-Verbose -Message (Get-DotFilesMessage 'Registering dynamic argument completer ...')
Register-ArgumentCompleter -Native -CommandName 'dotnet' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)

    & dotnet complete --position $cursorPosition $commandAst.ToString() | ForEach-Object {
        [Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
    }
}

Complete-DotFilesSection
