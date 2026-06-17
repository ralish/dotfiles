# Azure CLI
# https://learn.microsoft.com/en-au/cli/azure/
# https://github.com/Azure/azure-cli

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'Azure CLI'
    Command = 'az'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Disable telemetry
$Env:AZURE_CORE_COLLECT_TELEMETRY = 'false'

# Install the Azure CLI on Windows
# https://learn.microsoft.com/en-au/cli/azure/install-azure-cli-windows
Write-Verbose -Message (Get-DotFilesMessage 'Registering dynamic argument completer ...')
Register-ArgumentCompleter -Native -CommandName 'az' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)

    $Env:COMP_LINE = $commandAst
    $Env:COMP_POINT = $cursorPosition

    $AzCompletionFile = New-TemporaryFile
    $Env:ARGCOMPLETE_USE_TEMPFILES = 1
    $Env:_ARGCOMPLETE = 1
    $Env:_ARGCOMPLETE_IFS = "`n"
    $Env:_ARGCOMPLETE_SHELL = 'powershell'
    $Env:_ARGCOMPLETE_STDOUT_FILENAME = $AzCompletionFile
    $Env:_ARGCOMPLETE_SUPPRESS_SPACE = 0

    $null = & az 2>&1
    Get-Content -LiteralPath $AzCompletionFile | Sort-Object | ForEach-Object {
        [Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
    }

    $Env:COMP_LINE = $Env:COMP_POINT = $AzCompletionFile = $Env:ARGCOMPLETE_USE_TEMPFILES = $Env:_ARGCOMPLETE = $Env:_ARGCOMPLETE_IFS = $Env:_ARGCOMPLETE_SHELL = $Env:_ARGCOMPLETE_STDOUT_FILENAME = $Env:_ARGCOMPLETE_SUPPRESS_SPACE = $null
}

Complete-DotFilesSection
