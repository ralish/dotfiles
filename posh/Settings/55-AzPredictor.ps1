# Az Predictor
# https://learn.microsoft.com/en-au/powershell/azure/predictor-overview
# https://github.com/Azure/azure-powershell

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'Az Predictor'
    Module          = 'Az.Tools.Predictor', 'PSReadLine'
    PwshMinVersion  = 7.2
    ForceTestModule = $true
    Async           = $true
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Intelligent context-aware command completion with Az Predictor
# https://learn.microsoft.com/en-au/powershell/azure/az-predictor
Function Import-AzPredictor {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if ((Get-Module -Name 'PSReadLine').Version -lt [Version]::new('2.2.2')) {
        Write-DotFilesMessage -Type 'Verbose' -Message 'Skipping as PSReadLine module is not v2.2.2 or later.'
        return
    }

    if ((Get-PSReadLineOption).PredictionSource -ne 'HistoryAndPlugin') {
        Write-DotFilesMessage -Type 'Verbose' -Message 'Skipping as PredictionSource for PSReadLine is not set to "HistoryAndPlugin".'
        return
    }

    try {
        # Suppress verbose output on import (global scope to catch everything)
        $VerboseOriginal = $Global:VerbosePreference
        $Global:VerbosePreference = 'SilentlyContinue'

        Import-Module -Name 'Az.Tools.Predictor' -Scope 'Global' -ErrorAction 'Stop' -Verbose:$false
    } catch {
        Write-DotFilesMessage -Type 'Warning' -Message 'Failed to import Az.Tools.Predictor module.'
    } finally {
        $Global:VerbosePreference = $VerboseOriginal
    }
}

Import-AzPredictor

Remove-Item -LiteralPath 'Function:\Import-AzPredictor'
Complete-DotFilesSection
