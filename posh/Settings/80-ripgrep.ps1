$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'ripgrep'
    Command = @('rg')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Path to our ripgrep configuration
$env:RIPGREP_CONFIG_PATH = Join-Path -Path $HOME -ChildPath '.ripgreprc'

Function Get-RipgrepCompletionPath {
    [CmdletBinding()]
    [OutputType([Void], [IO.FileInfo])]
    Param()

    try {
        $RgCommand = Get-Command -Name 'rg'
        if (!$RgCommand.Name.EndsWith('.ps1')) {
            return
        }

        $RgScriptPath = Get-Item -LiteralPath $RgCommand.Path
        if (!$RgScriptPath.Directory.Name -eq 'shims') {
            return
        }

        $RgCompletionPath = Join-Path -Path $RgScriptPath.Directory.Parent.FullName -ChildPath 'apps\ripgrep\current\complete\_rg.ps1'
        $RgCompletion = Get-Item -LiteralPath $RgCompletionPath
        if ($RgCompletion -is [IO.FileInfo]) {
            return $RgCompletion
        }
    } catch {
        Write-Warning -Message (Get-DotFilesMessage -Message 'Skipping ripgrep completion as unable to locate _rg.ps1.')
    }
}

# Attempt to load ripgrep completion (Windows only)
if (Test-IsWindows) {
    $RgCompletion = Get-RipgrepCompletionPath
    if ($RgCompletion) {
        . $RgCompletion
    }
    Remove-Variable -Name 'RgCompletion'
}

Remove-Item -Path 'Function:\Get-RipgrepCompletionPath'
Complete-DotFilesSection
