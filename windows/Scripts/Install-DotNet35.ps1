<#
    Install .NET Framework 3.5 on Windows releases for which it's an optional
    operating system component.
#>

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void], [String[]])]
Param(
    [ValidateNotNullOrEmpty()]
    [String]$SxsPath
)

# The implicit import of the `CimCmdlets` module that may occur below triggers
# several "What if" outputs under Windows PowerShell, even though `Get-Command`
# doesn't support `-WhatIf`. We can use `$WhatIfPreference` to suppress them.
$WhatIfOriginal = $WhatIfPreference
$WhatIfPreference = $false

$WmiCommand = 'Get-CimInstance'
if (!(Get-Command -Name $WmiCommand -ErrorAction 'Ignore')) {
    $WmiCommand = 'Get-WmiObject'
}

$WhatIfPreference = $WhatIfOriginal

$Win32OpSys = & $WmiCommand -Class 'Win32_OperatingSystem' -Property 'BuildNumber' -Verbose:$false
$BuildNumber = [Int]$Win32OpSys.BuildNumber

$DismParams = '/Online', '/Enable-Feature', '/FeatureName:NetFx3'

if ($SxsPath) {
    $DismParams += "/Source:$SxsPath"
}

# The `/All` parameter is only available from Windows 8 / Server 2012
if ($BuildNumber -ge 9200) {
    $DismParams += '/All'
}

if ($PSCmdlet.ShouldProcess("dism.exe $($DismParams -join ' ')", 'Start')) {
    $Dism = Start-Process -FilePath 'dism.exe' -ArgumentList $DismParams -NoNewWindow -Wait -PassThru -ErrorAction 'Stop'
    if ($Dism.ExitCode -ne 0) {
        $ErrMsg = "dism.exe exited with non-zero exit code: $($Dism.ExitCode)"
        $ErrCat = [Management.Automation.ErrorCategory]::FromStdErr
        $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'DismFailed', $ErrCat, $Dism.ExitCode)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}
