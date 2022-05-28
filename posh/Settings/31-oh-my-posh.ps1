$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'oh-my-posh'
    Command = @('oh-my-posh')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Name of theme to use
$OmpThemeName = 'slim'

Function Get-OhMyPoshConfig {
    [CmdletBinding()]
    Param()

    if (!$env:POSH_THEMES_PATH) {
        $OmpBasePath = Split-Path -Path (Split-Path -Path (Get-Command -Name oh-my-posh).Source)
        $env:POSH_THEMES_PATH = Join-Path -Path $OmpBasePath -ChildPath 'themes'
    }

    $OmpThemeFile = '{0}.omp.json' -f $OmpThemeName
    $OmpThemePath = Join-Path -Path $env:POSH_THEMES_PATH -ChildPath $OmpThemeFile

    return $OmpThemePath
}

# Suppress verbose output on loading
$VerboseOriginal = $VerbosePreference
$VerbosePreference = 'SilentlyContinue'

# Load oh-my-posh
& oh-my-posh init pwsh --config (Get-OhMyPoshConfig) | Invoke-Expression

# Restore the original $VerbosePreference setting
$VerbosePreference = $VerboseOriginal
Remove-Variable -Name VerboseOriginal

Remove-Item -Path Function:\Get-OhMyPoshConfig
Remove-Variable -Name OmpThemeName
Complete-DotFilesSection
