$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'PuTTY'
    Platform = 'Windows'
    Command  = @('putty')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

Register-ArgumentCompleter -Native -CommandName 'plink', 'pscp', 'psftp', 'putty' -ScriptBlock {
    Param($wordToComplete, $commandAst, $cursorPosition)

    try {
        $SessionsKey = Get-Item -Path 'HKCU:\Software\SimonTatham\PuTTY\Sessions' -ErrorAction Stop
    } catch {
        return
    }

    # PowerShell implementation to match PuTTY internal method:
    # void unescape_registry_key(const char *in, strbuf *out)
    $Sessions = $SessionsKey.GetSubKeyNames() | ForEach-Object {
        $SessionName = $_
        $Result = [Text.StringBuilder]::new($SessionName.Length)

        for ($Index = 0; $Index -lt $SessionName.Length) {
            if ($SessionName[$Index] -ne '%') {
                $null = $Result.Append($SessionName[$Index++])
                continue
            }

            $null = $Result.Append([Char][Convert]::ToByte($SessionName.Substring(++$Index, 2), 16))
            $Index += 2
        }

        $Result.ToString()
    }

    $SessionName = $wordToComplete.Trim('"', "'")
    $Sessions | Where-Object { $_.StartsWith($SessionName, [StringComparison]::CurrentCultureIgnoreCase) } | ForEach-Object {
        $completionText = $listItemText = $toolTip = $_

        if ($listItemText.Contains(' ')) {
            $completionText = "'{0}'" -f $listItemText
        }

        [Management.Automation.CompletionResult]::new($completionText, $listItemText, 'ParameterValue', $toolTip)
    }
}

Complete-DotFilesSection
