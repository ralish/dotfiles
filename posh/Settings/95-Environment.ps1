$null = Start-DotFilesSection -Type 'Settings' -Name 'Environment'

# Miscellaneous environment configuration
Function Initialize-Environment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Set the `EDITOR` environment variable to an available preferred editor
    foreach ($Editor in $Global:DotFilesPreferredEditors) {
        if (Get-Command -Name $Editor -ErrorAction 'Ignore') {
            $Env:EDITOR = $Editor
            break
        }
    }

    if ([String]::IsNullOrWhiteSpace($Env:EDITOR)) {
        Write-DotFilesMessage -Type 'Warning' -Message "No available preferred editor was found: $($Global:DotFilesPreferredEditors -join ', ')"
    }
}

Initialize-Environment

Remove-Item -LiteralPath 'Function:\Initialize-Environment'
Complete-DotFilesSection
