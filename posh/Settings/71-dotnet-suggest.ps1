# dotnet-suggest
# https://github.com/dotnet/command-line-api

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'dotnet-suggest'
    Command = 'dotnet-suggest'
    Async   = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup `dotnet-suggest` configuration
Function Initialize-DotNetSuggest {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Tab completion for System.CommandLine
    # https://learn.microsoft.com/en-au/dotnet/standard/commandline/how-to-enable-tab-completion
    $Env:DOTNET_SUGGEST_SCRIPT_VERSION = '1.0.2'

    # Determine the list of apps registered for suggestions
    $RegisteredAppsRaw = & dotnet-suggest list | Out-String
    $RegisteredAppsSplit = $RegisteredAppsRaw.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
    $RegisteredApps = $RegisteredAppsSplit | Where-Object {
        # `dotnet` has its own argument completion support
        $PSItem -ne 'dotnet' -and
        # Almost always `dotnet <x>` aliases which don't work anyway
        # https://github.com/dotnet/command-line-api/issues/2302
        $PSItem -notmatch '^dotnet '
    }

    Write-DotFilesMessage -Type 'Verbose' -Message "Registering dynamic argument completer for $($RegisteredApps.Count) command(s)."
    Register-ArgumentCompleter -Native -CommandName $RegisteredApps -ScriptBlock {
        Param($wordToComplete, $commandAst, $cursorPosition)

        $CommandPath = (Get-Command -Name $commandAst.CommandElements[0]).Source
        $CommandArgs = $CommandAst.Extent.ToString().Replace('"', '\"')
        & dotnet-suggest get -e $CommandPath --position $cursorPosition -- $CommandArgs | ForEach-Object {
            [Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
        }
    }
}

Initialize-DotNetSuggest

Remove-Item -LiteralPath 'Function:\Initialize-DotNetSuggest'
Complete-DotFilesSection
