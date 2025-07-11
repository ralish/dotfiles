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
$OmpThemeName = 'oh-my-posh'

Function Get-OmpConfig {
    [CmdletBinding()]
    [OutputType([Void], [String])]
    Param(
        [Parameter(Mandatory)]
        [String]$ThemeName
    )

    # Check if the theme exists in our profile directory. If it does, we can
    # immediately return and skip figuring out where the bundled themes are.
    $OmpThemePath = Join-Path -Path (Split-Path -Path $PROFILE -Parent) -ChildPath ('{0}.omp.json' -f $ThemeName)
    $OmpThemeFile = Get-Item -LiteralPath $OmpThemePath -ErrorAction Ignore
    if ($OmpThemeFile -is [IO.FileInfo]) {
        return $OmpThemePath
    }

    if ($env:POSH_THEMES_PATH) {
        $OmpThemeDir = $env:POSH_THEMES_PATH
        $Message = 'Using POSH_THEMES_PATH environment variable: {0}' -f $env:POSH_THEMES_PATH
    } else {
        $OmpBinFilePath = (Get-Command -Name 'oh-my-posh').Source
        $OmpPathElements = $OmpBinFilePath.Split([IO.Path]::DirectorySeparatorChar)

        if ($OmpPathElements -contains 'scoop') {
            $OmpBasePath = Split-Path -Path (Split-Path -Path $OmpBinFilePath)
            $Message = 'Detected Scoop installation of oh-my-posh.'
        } elseif ($OmpPathElements -contains '.linuxbrew') {
            $OmpBinFileItem = Get-Item -LiteralPath $OmpBinFilePath
            $OmpBinRealPath = Resolve-Path -Path (Join-Path -Path (Split-Path -Path $OmpBinFileItem.FullName -Parent) -ChildPath $OmpBinFileItem.Target)
            $OmpBasePath = Split-Path -Path (Split-Path -Path $OmpBinRealPath.Path)
            $Message = 'Detected Homebrew installation of oh-my-posh.'
        } else {
            $Message = 'Unable to determine oh-my-posh themes path.'
            Write-Warning -Message (Get-DotFilesMessage -Message $Message)
            return
        }

        $OmpThemeDir = Join-Path -Path $OmpBasePath -ChildPath 'themes'
    }

    # Output the detected oh-my-posh themes path
    Write-Verbose -Message (Get-DotFilesMessage -Message $Message)

    $OmpThemePath = Join-Path -Path $OmpThemeDir -ChildPath ('{0}.omp.json' -f $ThemeName)
    $OmpThemeFile = Get-Item -LiteralPath $OmpThemePath -ErrorAction Ignore
    if ($OmpThemeFile -isnot [IO.FileInfo]) {
        $Message = 'Expected oh-my-posh theme path is not a file: {0}' -f $OmpThemePath
        Write-Warning -Message (Get-DotFilesMessage -Message $Message)
        return
    }

    return $OmpThemePath
}

# Retrieve oh-my-posh config
$OmpConfig = Get-OmpConfig -ThemeName $OmpThemeName
if ($OmpConfig) {
    Write-Verbose -Message (Get-DotFilesMessage -Message ('Using theme file: {0}' -f $OmpConfig))
}

# Suppress verbose output on loading
$VerboseOriginal = $Global:VerbosePreference
$Global:VerbosePreference = 'SilentlyContinue'

# Load oh-my-posh
if ($OmpConfig) {
    & oh-my-posh init pwsh --config $OmpConfig | Invoke-Expression # DevSkim: ignore DS104456
} else {
    & oh-my-posh init pwsh | Invoke-Expression # DevSkim: ignore DS104456
}

# Restore the original $VerbosePreference setting
$Global:VerbosePreference = $VerboseOriginal
Remove-Variable -Name 'VerboseOriginal'

# Enable posh-git support if previously imported
if (Get-Module -Name 'posh-git' -Verbose:$false) {
    $env:POSH_GIT_ENABLED = $true
}

Remove-Item -Path 'Function:\Get-OmpConfig'
Remove-Variable -Name 'OmpConfig', 'OmpThemeName'
Complete-DotFilesSection
