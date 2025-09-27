$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'dotnet-suggest'
    Command = @('dotnet-suggest')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Tab completion for System.CommandLine
# https://learn.microsoft.com/en-au/dotnet/standard/commandline/how-to-enable-tab-completion
$env:DOTNET_SUGGEST_SCRIPT_VERSION = '1.0.2'

# Determine the list of apps registered for suggestions and exclude the .NET
# CLI (dotnet) as it has its own built-in support.
$RegisteredAppsRaw = (dotnet-suggest list) | Out-String
$RegisteredAppsSplit = $RegisteredAppsRaw.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
$RegisteredApps = $RegisteredAppsSplit | Where-Object {
    # dotnet has its own argument completion support
    $_ -ne 'dotnet' -and
    # Almost always "dotnet <x>" aliases which don't work anyway
    # https://github.com/dotnet/command-line-api/issues/2302
    $_ -notmatch ' '
}

Register-ArgumentCompleter -Native -CommandName $RegisteredApps -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)
    $Local:CommandPath = (Get-Command -Name $commandAst.CommandElements[0]).Source
    $Local:CommandArgs = $CommandAst.Extent.ToString().Replace('"', '\"')
    dotnet-suggest get -e $Local:CommandPath --position $cursorPosition -- $Local:CommandArgs | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Remove-Variable -Name 'RegisteredApps', 'RegisteredAppsRaw', 'RegisteredAppsSplit'
Complete-DotFilesSection
