$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Az Predictor'
    Module          = @('Az', 'Az.Tools.Predictor')
    ForceTestModule = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Intelligent context-aware command completion with Az Predictor
# https://learn.microsoft.com/en-us/powershell/azure/az-predictor
if ($PSVersionTable.PSVersion -lt [Version]::new('7.2')) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping as PowerShell is not v7.2 or later.')
    return
}

if (!(Get-Module -Name 'PSReadLine')) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping as PSReadLine module is not present.')
    return
}

if ((Get-Module -Name 'PSReadLine').Version -lt [Version]::new('2.2.2')) {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping as PSReadLine module is not v2.2.2 or later.')
    return
}

if ((Get-PSReadLineOption).PredictionSource -ne 'HistoryAndPlugin') {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping as PSReadLine PredictionSource option is not set to "HistoryAndPlugin".')
    return
}

# Suppress verbose output on import
$VerboseOriginal = $Global:VerbosePreference
$Global:VerbosePreference = 'SilentlyContinue'

try {
    Import-Module -Name 'Az.Tools.Predictor' -ErrorAction Stop -Verbose:$false
} catch {
    Write-Warning -Message (Get-DotFilesMessage -Message 'Failed to import Az.Tools.Predictor module.')
} finally {
    # Restore the original $VerbosePreference setting
    $Global:VerbosePreference = $VerboseOriginal
}

Complete-DotFilesSection
