# Oh My Posh
# https://ohmyposh.dev/
# https://github.com/JanDeDobbeleer/oh-my-posh

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'Oh My Posh'
    Command = 'oh-my-posh'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup Oh My Posh configuration
Function Initialize-OhMyPosh {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Name of theme to use
    $ThemeName = 'oh-my-posh'

    # Retrieve Oh My Posh theme path
    $ThemePath = Get-OhMyPoshThemePath -ThemeName $ThemeName
    if ($ThemePath) {
        Write-DotFilesMessage -Type 'Verbose' -Message "Theme path: ${ThemePath}"
    }

    try {
        # Suppress verbose output on import (global scope to catch everything)
        $VerboseOriginal = $Global:VerbosePreference
        $Global:VerbosePreference = 'SilentlyContinue'

        # Load Oh My Posh
        if ($ThemePath) {
            & oh-my-posh init pwsh --config $ThemePath | Invoke-Expression # DevSkim: ignore DS104456
        } else {
            & oh-my-posh init pwsh | Invoke-Expression # DevSkim: ignore DS104456
        }
    } finally {
        $Global:VerbosePreference = $VerboseOriginal
    }

    # Enable `posh-git` support if imported
    if (Get-Module -Name 'posh-git' -Verbose:$false) {
        $Env:POSH_GIT_ENABLED = $true
    }
}

# Attempt to retrieve the path to a theme given its name
Function Get-OhMyPoshThemePath {
    [CmdletBinding()]
    [OutputType([Void], [String])]
    Param(
        [Parameter(Mandatory)]
        [String]$ThemeName
    )

    # Check if the theme exists in our profile directory. If it does, we can
    # immediately return and skip figuring out where the bundled themes are.
    $ThemePath = Join-Path -Path (Split-Path -Path $PROFILE -Parent) -ChildPath "${ThemeName}.omp.json"
    $ThemeFile = Get-Item -LiteralPath $ThemePath -ErrorAction 'Ignore'
    if ($ThemeFile -is [IO.FileInfo]) {
        return $ThemePath
    }

    if ($Env:POSH_THEMES_PATH) {
        $ThemeDir = $Env:POSH_THEMES_PATH
        $Msg = 'Using POSH_THEMES_PATH environment variable.'
    } else {
        $BinFilePath = (Get-Command -Name 'oh-my-posh').Source
        $PathElements = $BinFilePath.Split([IO.Path]::DirectorySeparatorChar)

        if ($PathElements -contains 'scoop') {
            $BasePath = Split-Path -Path (Split-Path -Path $BinFilePath)
            $Msg = 'Detected Scoop installation.'
        } elseif ($PathElements -contains '.linuxbrew') {
            $BinFileItem = Get-Item -LiteralPath $BinFilePath -ErrorAction 'Ignore'
            if ($BinFileItem -isnot [IO.FileInfo]) {
                $ExcMsg = "Detected Homebrew installation but path to oh-my-posh binary is not a file: ${BinFilePath}"
                $ErrExc = [IO.FileNotFoundException]::new($ExcMsg, $BinFilePath.Name)
                $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFound', $ErrCat, $BinFilePath)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $BinRealPath = Resolve-Path -Path (Join-Path -Path (Split-Path -Path $BinFileItem.FullName -Parent) -ChildPath $BinFileItem.Target)
            $BasePath = Split-Path -Path (Split-Path -Path $BinRealPath.Path)
            $Msg = 'Detected Homebrew installation.'
        } else {
            $Msg = 'Unable to determine themes directory.'
            Write-DotFilesMessage -Type 'Warning' -Message $Msg
            return
        }

        $ThemeDir = Join-Path -Path $BasePath -ChildPath 'themes'
    }

    Write-DotFilesMessage -Type 'Verbose' -Message $Msg
    Write-DotFilesMessage -Type 'Verbose' -Message "Themes directory: ${ThemeDir}"

    $ThemePath = Join-Path -Path $ThemeDir -ChildPath "${ThemeName}.omp.json"
    $ThemeFile = Get-Item -LiteralPath $ThemePath -ErrorAction 'Ignore'
    if ($ThemeFile -isnot [IO.FileInfo]) {
        $Msg = "Expected theme path is not a file: ${ThemePath}"
        Write-DotFilesMessage -Type 'Warning' -Message $Msg
        return
    }

    return $ThemePath
}

Initialize-OhMyPosh

Remove-Item -LiteralPath 'Function:\Get-OhMyPoshThemePath', 'Function:\Initialize-OhMyPosh'
Complete-DotFilesSection
