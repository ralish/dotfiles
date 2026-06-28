# .NET CLI
# https://learn.microsoft.com/en-au/dotnet/core/tools/
# https://github.com/dotnet/sdk

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = '.NET CLI'
    Command = 'dotnet'
    Async   = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Disable telemetry
$Env:DOTNET_CLI_TELEMETRY_OPTOUT = 'true'

# Setup .NET CLI configuration
Function Initialize-DotNetCli {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Assume if there's an existing native completions script we can use it. This
    # avoids a potentially expensive process launch of `dotnet` to retrieve the
    # version, which tells us whether to use dynamic or native completions.
    $CompletionsFile = Join-Path -Path $Global:PoshCompletionsPath -ChildPath 'dotnet.ps1'
    if (!$Env:DOTFILES_REBUILD_COMPLETIONS -and (Test-Path -LiteralPath $CompletionsFile -PathType 'Leaf')) {
        $CompletionsType = 'Native'
    } else {
        $CompletionsType = Get-DotNetCliCompletionsType
    }

    # Import the appropriate type of completions
    Import-DotNetCliCompletions -Type $CompletionsType

    # Clean-up the completions setup functions
    Remove-Item -LiteralPath 'Function:\Get-DotNetCliCompletionsType', 'Function:\Import-DotNetCliCompletions'
}

# Determine the type of argument completions to use
Function Get-DotNetCliCompletionsType {
    [CmdletBinding()]
    [OutputType([String])]
    Param()

    $VersionArgs = @('--version')
    $VersionCmd = "dotnet $($VersionArgs -join ' ')"

    try {
        # If we're running this version of `dotnet` for the first time the
        # welcome banner will display which may cause issues issues with output
        # parsing.
        if ($Env:DOTNET_NOLOGO) {
            $OriginalNoLogo = $Env:DOTNET_NOLOGO
        } else {
            $OriginalNoLogo = $null
        }
        $Env:DOTNET_NOLOGO = 'true'

        $CliVersionRaw = (& dotnet @VersionArgs 2>&1) -join ''
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to retrieve .NET version (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $VersionCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $CliVersion = $null
        if (![Version]::TryParse($CliVersionRaw, [Ref]$CliVersion)) {
            $ErrMsg = "Failed to parse .NET version: ${CliVersionRaw}"
            $ErrExc = [FormatException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ParserError
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'VersionParseFailed', $ErrCat, $CliVersionRaw)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    } finally {
        if ($OriginalNoLogo) {
            $Env:DOTNET_NOLOGO = $OriginalNoLogo
        } else {
            $Env:DOTNET_NOLOGO = $null
        }
    }

    # From .NET 10 we can use native completions which are much faster
    if ($CliVersion -ge '10.0') {
        return 'Native'
    }

    # Only dynamic completions are available prior to .NET 10
    return 'Dynamic'
}

# How to enable tab completion for the .NET CLI
# https://learn.microsoft.com/en-au/dotnet/core/tools/enable-tab-autocomplete
Function Import-DotNetCliCompletions {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [ValidateSet('Dynamic', 'Native')]
        [String]$Type
    )

    switch ($Type) {
        'Dynamic' {
            Write-DotFilesMessage -Type 'Verbose' -Message 'Registering dynamic argument completer ...'
            Register-ArgumentCompleter -Native -CommandName 'dotnet' -ScriptBlock {
                Param($wordToComplete, $commandAst, $cursorPosition)

                & dotnet complete --position $cursorPosition $commandAst.ToString() | ForEach-Object {
                    [Management.Automation.CompletionResult]::new($PSItem, $PSItem, 'ParameterValue', $PSItem)
                }
            }
        }

        'Native' {
            if ($Env:DOTFILES_REBUILD_COMPLETIONS -or !(Test-Path -LiteralPath $CompletionsFile -PathType 'Leaf')) {
                Write-DotFilesMessage -Type 'Verbose' -Message 'Building native completions script ...'
                & dotnet completions script pwsh | Out-File -FilePath $CompletionsFile -Encoding 'utf8'
            }

            Write-DotFilesMessage -Type 'Verbose' -Message 'Registering native argument completer ...'
            Get-Content -LiteralPath $CompletionsFile | Out-String | Invoke-Expression # DevSkim: ignore DS104456
        }
    }
}

Initialize-DotNetCli

Remove-Item -LiteralPath 'Function:\Initialize-DotNetCli'
Complete-DotFilesSection
