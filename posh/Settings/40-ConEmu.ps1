# ConEmu
# https://conemu.github.io/
# https://github.com/ConEmu/ConEmu

$DotFilesSection = @{
    Type        = 'Settings'
    Name        = 'ConEmu'
    Platform    = 'Windows'
    Environment = @{ ConEmuANSI = 'ON' }
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup ConEmu configuration
Function Initialize-ConEmu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Extending the PowerShell Prompt
    # https://conemu.github.io/en/PowershellPrompt.html
    $Global:ConEmuPrompt = {
        # Mark end of prompt
        # `OSC ConEmu ; PromptStart ST`
        $Prompt = "$([Char]27)]9;12`a"

        # Mark current working directory
        $CurLoc = $ExecutionContext.SessionState.Path.CurrentLocation
        if ($CurLoc.Provider.Name -eq 'FileSystem') {
            # `OSC ConEmu ; CurrentDir ; "<Cwd>" ST`
            $Prompt += "$([Char]27)]9;9;`"${CurLoc}`"`a"
        }

        return $Prompt
    }
}

Initialize-ConEmu

Remove-Item -LiteralPath 'Function:\Initialize-ConEmu'
Complete-DotFilesSection
