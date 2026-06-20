# PuTTY
# https://www.chiark.greenend.org.uk/~sgtatham/putty/

$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'PuTTY'
    Command  = 'putty'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup PuTTY configuration
Function Initialize-PuTTY {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Custom argument completer to complete session names using sessions stored
    # in the Windows registry. This of course only works on Windows, as on
    # non-Windows platforms PuTTY stores session configurations in files.
    Write-DotFilesMessage -Type 'Verbose' -Message 'Registering native argument completer ...'
    $PuttyCmds = 'plink', 'pscp', 'psftp', 'putty'
    Register-ArgumentCompleter -Native -CommandName $PuttyCmds -ScriptBlock {
        Param($wordToComplete, $commandAst, $cursorPosition)

        # Registry key for saved sessions
        $SessionsPath = 'HKCU:\Software\SimonTatham\PuTTY\Sessions'

        # No saved sessions
        try {
            $SessionsKey = Get-Item -LiteralPath $SessionsPath -ErrorAction 'Stop'
        } catch { return }

        # PowerShell implementation to match PuTTY internal method:
        # `void unescape_registry_key(const char *in, strbuf *out)`
        $Sessions = $SessionsKey.GetSubKeyNames() | ForEach-Object {
            $SessionName = $PSItem
            $Result = [Text.StringBuilder]::new($SessionName.Length)

            for ($i = 0; $i -lt $SessionName.Length) {
                if ($SessionName[$i] -ne '%') {
                    $null = $Result.Append($SessionName[$i++])
                    continue
                }

                $null = $Result.Append([Char][Convert]::ToByte($SessionName.Substring(++$i, 2), 16))
                $i += 2
            }

            $Result.ToString()
        }

        $SessionName = $wordToComplete.Trim('"', "'")
        $Sessions | Where-Object {
            $PSItem.StartsWith($SessionName, [StringComparison]::CurrentCultureIgnoreCase)
        } | ForEach-Object {
            $completionText = $PSItem
            if ($completionText.Contains(' ')) {
                $completionText = "'${completionText}'"
            }

            [Management.Automation.CompletionResult]::new($completionText, $PSItem, 'ParameterValue', $PSItem)
        }
    }
}

Initialize-PuTTY

Remove-Item -LiteralPath 'Function:\Initialize-PuTTY'
Complete-DotFilesSection
