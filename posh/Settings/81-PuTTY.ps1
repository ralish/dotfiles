if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Get-Command -Name putty -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping PuTTY settings as unable to locate putty.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading PuTTY settings ...')

Register-ArgumentCompleter -Native -CommandName putty -ScriptBlock {
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
