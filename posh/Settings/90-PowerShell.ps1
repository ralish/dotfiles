# PowerShell
# https://learn.microsoft.com/en-au/powershell/
# https://github.com/PowerShell/PowerShell

$null = Start-DotFilesSection -Type 'Settings' -Name 'PowerShell'

# Save the output of the last command in a global variable
Function Out-Default {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '')]
    [OutputType([Void])]
    Param()

    $Input | Tee-Object -Variable 'LastObject' | Microsoft.PowerShell.Core\Out-Default
    $Global:LastObject = $LastObject
}

# Number of elements to enumerate when displaying arrays
$FormatEnumerationLimit = 5

# Set configuration specific to PowerShell edition
switch ($PSVersionTable.PSEdition) {
    'Core' {
        # `Update-Help`: `en-GB` locale is not available
        $PSDefaultParameterValues['Update-Help:UICulture'] = 'en-US'
    }

    'Desktop' {
        # Use UTF-8 as the output encoding
        $OutputEncoding = [Text.UTF8Encoding]::new()

        # `Out-File`: Default to UTF-8 encoding
        $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
    }

    Default {
        Write-Warning -Message (Get-DotFilesMessage -Message 'Unknown PowerShell edition.')
    }
}

Complete-DotFilesSection
