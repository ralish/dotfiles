if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Get-Command -Name rg -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ripgrep settings as unable to locate rg.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading ripgrep settings ...')

# Path to our ripgrep configuration
$env:RIPGREP_CONFIG_PATH = Join-Path -Path $HOME -ChildPath '.ripgreprc'

# Attempt to load ripgrep completion (Windows only)
if (Test-IsWindows) {
    try {
        $RgCommand = Get-Command -Name rg
        $RgCompletion = [String]::Empty

        if ($RgCommand.Name.EndsWith('.ps1')) {
            $RgScriptPath = Get-Item -LiteralPath $RgCommand.Path

            if ($RgScriptPath.Directory.Name -eq 'shims') {
                $RgCompletion = Join-Path -Path $RgScriptPath.Directory.Parent.FullName -ChildPath 'apps\ripgrep\current\complete\_rg.ps1'
            }
        }

        . $RgCompletion
    } catch {
        Write-Warning -Message (Get-DotFilesMessage -Message 'Skipping ripgrep completion as unable to locate _rg.ps1.')
    } finally {
        Remove-Variable -Name 'RgCommand', 'RgCompletion', 'RgScriptPath' -ErrorAction Ignore
    }
}
