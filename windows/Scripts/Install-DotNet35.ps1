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
# several "What if" outputs under Windows PowerShell, even though
# `Get-CimInstance` doesn't support `-WhatIf`. As this cmdlet doesn't modify
# any state we temporarily disable `WhatIf` mode.
try {
    $WhatIfOriginal = $WhatIfPreference
    $WhatIfPreference = $false

    $Win32OpSys = Get-CimInstance -Class 'Win32_OperatingSystem' -Property 'BuildNumber' -ErrorAction 'Stop' -Verbose:$false
} catch {
    $PSCmdlet.ThrowTerminatingError($PSItem)
} finally {
    $WhatIfPreference = $WhatIfOriginal
}

$DismArgs = '/Online', '/Enable-Feature', '/FeatureName:NetFx3'

if ($SxsPath) {
    $DismArgs += '/Source:"{0}"' -f $SxsPath
}

# The `/All` parameter is only available from Windows 8 / Server 2012
if ([UInt32]$Win32OpSys.BuildNumber -ge 9200) {
    $DismArgs += '/All'
}

$DismCmd = "dism $($DismArgs -join ' ')"

if ($PSCmdlet.ShouldProcess($DismCmd, 'Start')) {
    try {
        $DismExe = Join-Path -Path $Env:SystemRoot -ChildPath 'System32\dism.exe'
        $Dism = Start-Process -FilePath $DismExe -ArgumentList $DismArgs -NoNewWindow -Wait -PassThru -ErrorAction 'Stop'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    switch ($Dism.ExitCode) {
        0 { } # Success
        3010 { Write-Warning -Message 'DISM completed successfully but the changes require a reboot.' }

        default {
            $ExcMsg = "DISM exited with non-zero exit code: $($Dism.ExitCode)"
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $DismCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}
