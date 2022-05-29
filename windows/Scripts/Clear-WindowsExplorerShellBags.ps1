<#
    Clear Windows Explorer shell bags.
#>

[CmdletBinding(SupportsShouldProcess)]
Param()

$RegPaths = @(
    'HKCU:\Software\Microsoft\Windows\Shell',
    'HKCU:\Software\Microsoft\Windows\ShellNoRoam',
    'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell'
)

if ([Environment]::Is64BitOperatingSystem) {
    $RegPaths += 'HKCU:\Software\Classes\Wow6432Node\Local Settings\Software\Microsoft\Windows\Shell'
}

foreach ($RegPath in $RegPaths) {
    $RegPathBags = Join-Path -Path $RegPath -ChildPath 'Bags'
    $RegPathBagMRU = Join-Path -Path $RegPath -ChildPath 'BagMRU'

    foreach ($RegPathToRemove in @($RegPathBags, $RegPathBagMRU)) {
        if ($PSCmdlet.ShouldProcess($RegPathToRemove, 'Remove')) {
            try {
                Remove-Item -Path $RegPathToRemove -Recurse -ErrorAction Stop
            } catch {
                switch -Regex ($PSItem.FullyQualifiedErrorId) {
                    '^PathNotFound,' { }
                    Default { throw }
                }
            }
        }
    }
}
