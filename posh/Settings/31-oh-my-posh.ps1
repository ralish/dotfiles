if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Get-Command -Name oh-my-posh -ErrorAction Ignore)) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping oh-my-posh settings as unable to locate oh-my-posh.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading oh-my-posh settings ...')

# Name of theme to use
$OmpThemeName = 'slim'

if (!$env:POSH_THEMES_PATH) {
    $OmpBasePath = Split-Path -Path (Split-Path -Path (Get-Command -Name oh-my-posh).Source)
    $env:POSH_THEMES_PATH = Join-Path -Path $OmpBasePath -ChildPath 'themes'
}

$OmpThemeFile = '{0}.omp.json' -f $OmpThemeName
$OmpThemePath = Join-Path -Path $env:POSH_THEMES_PATH -ChildPath $OmpThemeFile

& oh-my-posh init pwsh --config $OmpThemePath | Invoke-Expression

Remove-Variable -Name 'OmpThemeName', 'OmpThemeFile', 'OmpThemePath'
