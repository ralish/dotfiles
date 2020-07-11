if (!(Get-Command -Name rg -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ripgrep settings as unable to locate rg.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading ripgrep settings ...')

$RgCommand = Get-Command -Name rg
$RgCompletion = [String]::Empty

if ($RgCommand.Name.EndsWith('.ps1')) {
    $RgScriptPath = Get-Item -Path $RgCommand.Path

    if ($RgScriptPath.Directory.Name -eq 'shims') {
        $RgCompletion = Join-Path -Path $RgScriptPath.Directory.Parent -ChildPath 'apps\ripgrep\current\complete\_rg.ps1'
    }
}

try {
    . $RgCompletion
} catch {
    Write-Warning -Message (Get-DotFilesMessage -Message 'Skipping ripgrep completion as unable to locate _rg.ps1.')
}

Remove-Variable -Name 'RgCommand', 'RgCompletion', 'RgScriptPath' -ErrorAction Ignore
