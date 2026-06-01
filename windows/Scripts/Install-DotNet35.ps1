<#
    Install .NET Framework 3.5 on Windows releases for which it's an optional
    operating system component.
#>

#Requires -Version 5.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param(
    [ValidateNotNullOrEmpty()]
    [String]$SxsPath
)

# The implicit import of the `CimCmdlets` module that may occur below triggers
# several "What if" outputs under Windows PowerShell, even though `Get-Command`
# doesn't support `-WhatIf`. We can use `$WhatIfPreference` to suppress them.
$WhatIfOriginal = $WhatIfPreference
$WhatIfPreference = $false
$Win32OpSys = Get-CimInstance -Class 'Win32_OperatingSystem' -Property 'BuildNumber' -Verbose:$false
$WhatIfPreference = $WhatIfOriginal

$DismExe = 'dism.exe'
$DismArgs = '/Online', '/Enable-Feature', '/FeatureName:NetFx3'

if ($SxsPath) {
    $DismArgs += "/Source:${SxsPath}"
}

# The `/All` parameter is only available from Windows 8 / Server 2012
if ([UInt32]$Win32OpSys.BuildNumber -ge 9200) {
    $DismArgs += '/All'
}

if ($PSCmdlet.ShouldProcess("${DismExe} $($DismArgs -join ' ')", 'Start')) {
    $Dism = Start-Process -FilePath $DismExe -ArgumentList $DismArgs -NoNewWindow -Wait -PassThru
    if ($Dism.ExitCode -ne 0) {
        $ErrMsg = "${DismExe} exited with non-zero exit code: $($Dism.ExitCode)"
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'DismCmdFailed', $ErrCat, "${DismExe} $($DismArgs -join ' ')")
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}
