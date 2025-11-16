Start-DotFilesSection -Type 'Settings' -Name 'PowerShell'

# Number of elements to enumerate when displaying arrays
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$FormatEnumerationLimit = 5

# Out-File: Default to UTF-8 encoding
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

if ($PSVersionTable.PSEdition -eq 'Core') {
    # Update-Help: en-GB locale is not available under Core
    $PSDefaultParameterValues['Update-Help:UICulture'] = 'en-US'
}

# Save the output of the last command in a variable
Function Out-Default {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '')]
    Param()

    $Input | Tee-Object -Variable 'LastObject' | Microsoft.PowerShell.Core\Out-Default
    $Global:LastObject = $LastObject
}

Complete-DotFilesSection
