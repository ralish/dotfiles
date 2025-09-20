<#
    Clear Windows Explorer shell bags.
#>

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param()

$BasePaths = @(
    'HKCU:\Software\Microsoft\Windows\Shell',
    'HKCU:\Software\Microsoft\Windows\ShellNoRoam',
    'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell'
)

if ([Environment]::Is64BitOperatingSystem) {
    $BasePaths += 'HKCU:\Software\Classes\Wow6432Node\Local Settings\Software\Microsoft\Windows\Shell'
}

foreach ($BasePath in $BasePaths) {
    $BagsPath = Join-Path -Path $BasePath -ChildPath 'Bags'
    $BagMRUPath = Join-Path -Path $BasePath -ChildPath 'BagMRU'

    foreach ($BagPath in @($BagsPath, $BagMRUPath)) {
        if ($PSCmdlet.ShouldProcess($BagPath, 'Remove')) {
            try {
                Remove-Item -Path $BagPath -Recurse -ErrorAction Stop
            } catch {
                switch -Regex ($PSItem.FullyQualifiedErrorId) {
                    '^PathNotFound,' { }
                    Default { throw }
                }
            }
        }
    }
}
