<#
    Enable/Disable the F1 key opening a web browser to search for "How to get
    help" on Bing.
#>

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param(
    [ValidateSet('Enable', 'Disable')]
    [String]$Operation
)

if (![Environment]::OSVersion.Version -eq 10) {
    throw 'Script is only valid for Windows 10 or later.'
}

$TypeLibPath = 'HKCR:\TypeLib\{8cec5860-07a1-11d9-b15e-000d56bfe6ee}'
$Architectures = @('win32')
if ([Environment]::Is64BitOperatingSystem) {
    $Architectures += 'win64'
}

$RemoveHKCRDrive = $false
if (!(Get-PSDrive -Name 'HKCR' -ErrorAction Ignore)) {
    $RemoveHKCRDrive = $true
    $null = New-PSDrive -Name 'HKCR' -PSProvider 'Registry' -Root 'HKEY_CLASSES_ROOT' -WhatIf:$false
}

foreach ($Architecture in $Architectures) {
    $ArchPath = '{0}\1.0\0\{1}' -f $TypeLibPath, $Architecture

    try {
        $null = Get-ItemProperty -Path $ArchPath -ErrorAction Stop
    } catch {
        Write-Warning -Message ('Failed to retrieve {0} registry key for AP Client 1.0 Type Library.' -f $Architecture)
        continue
    }

    if ($Operation -eq 'Enable') {
        if ($PSCmdlet.ShouldProcess('Enable F1 key opening web browser search for help')) {
            $HelpPanePath = Join-Path -Path $env:SystemRoot -ChildPath 'HelpPane.exe'
            Set-ItemProperty -Path $ArchPath -Name '(default)' -Value $HelpPanePath
        }
    } else {
        if ($PSCmdlet.ShouldProcess('Disable F1 key opening web browser search for help')) {
            Set-ItemProperty -Path $ArchPath -Name '(default)' -Value [String]::Empty
        }
    }
}

if ($RemoveHKCRDrive) {
    Remove-PSDrive -Name 'HKCR' -WhatIf:$false
}
