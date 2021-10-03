if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Get-Command -Name dotnet-suggest -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping dotnet-suggest settings as unable to locate dotnet-suggest.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading dotnet-suggest settings ...')

# dotnet-suggest
# https://github.com/dotnet/command-line-api/blob/main/docs/dotnet-suggest.md
$env:DOTNET_SUGGEST_SCRIPT_VERSION = '1.0.2'

$RegisteredApps = (dotnet-suggest list | Out-String).Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
Register-ArgumentCompleter -Native -CommandName $RegisteredApps -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)
    $CommandPath = (Get-Command -Name $commandAst.CommandElements[0]).Source
    $CommandArgs = $CommandAst.Extent.ToString().Replace('"', '\"')
    dotnet-suggest get -e $CommandPath --position $cursorPosition -- $CommandArgs | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Remove-Variable -Name 'RegisteredApps'
