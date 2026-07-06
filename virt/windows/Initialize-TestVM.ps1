<#
    Initialize a Windows VM with a configuration optimised for testing.
#>

#Requires -Version 3.0
#Requires -RunAsAdministrator

[CmdletBinding(DefaultParameterSetName = 'OptOut', SupportsShouldProcess)]
[OutputType([Void])]
Param(
    [Parameter(ParameterSetName = 'OptOut')]
    [ValidateSet(
        'ComponentStore',
        'DiskCleanup',
        'DotNetFramework',
        'Microsoft365',
        'PowerShell',
        'ShutdownCleanup',
        'SystemRestore',
        'WindowsDefender',
        'WindowsPower',
        'WindowsSecurity',
        'WindowsSettings',
        'WindowsUpdate'
    )]
    [String[]]$ExcludeTasks,

    [Parameter(ParameterSetName = 'OptIn', Mandatory)]
    [ValidateSet(
        'ComponentStore',
        'DiskCleanup',
        'DotNetFramework',
        'Microsoft365',
        'PowerShell',
        'ShutdownCleanup',
        'SystemRestore',
        'WindowsDefender',
        'WindowsPower',
        'WindowsSecurity',
        'WindowsSettings',
        'WindowsUpdate'
    )]
    [String[]]$IncludeTasks
)

Function Invoke-ComponentStoreCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    # Windows 7 / Server 2008 R2 or earlier
    if ($Script:WindowsBuildNumber -le 7601 -and !(Get-Command -Name 'cleanmgr.exe' -ErrorAction 'Ignore')) {
        Write-Host -ForegroundColor 'Yellow' '[Component Store] Skipping clean-up as unable to find cleanmgr.exe.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('Component Store clean-up', 'Invoke')) { return }

    # Windows 8 / Server 2012 or later
    if ($Script:WindowsBuildNumber -ge 9200) {
        Write-Host -ForegroundColor 'Green' -NoNewline '[Component Store] Running clean-up via DISM ...'
        $DismExe = 'dism.exe'
        $DismArgs = '/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase'
        & $DismExe @DismArgs
        if ($LASTEXITCODE -ne 0) {
            $ExcMsg = "${DismExe} exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = New-Object -TypeName 'Exception' -ArgumentList $ExcMsg
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'NativeCommandFailed', $ErrCat, "${DismExe} $($DismArgs -join ' ')"
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Host
        return
    }

    try {
        Write-Host -ForegroundColor 'Green' '[Component Store] Running clean-up via Disk Clean-up ...'
        Set-DiskCleanupProfile -Number 1000 -IncludeCategories 'Update Cleanup'
        $CleanMgrExe = 'cleanmgr.exe'
        $CleanMgrArgs = '/sagerun:1000'
        $CleanMgr = Start-Process -FilePath $CleanMgrExe -ArgumentList $CleanMgrArgs -Wait -PassThru -ErrorAction 'Stop'
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    } finally {
        Remove-DiskCleanupProfile -Number 1000
    }

    if ($CleanMgr.ExitCode -ne 0) {
        $ExcMsg = "${CleanMgrExe} exited with non-zero exit code: $($CleanMgr.ExitCode)"
        $ErrExc = New-Object -TypeName 'Exception' -ArgumentList $ExcMsg
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'NativeCommandFailed', $ErrCat, "${CleanMgrExe} ${CleanMgrArgs}"
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}

Function Invoke-DiskCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if (!(Get-Command -Name 'cleanmgr.exe' -ErrorAction 'Ignore')) {
        Write-Host -ForegroundColor 'Yellow' '[Disk Clean-up] Skipping as unable to find cleanmgr.exe.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('Disk Clean-up', 'Invoke')) { return }

    $ExcludeCategories = @(
        'DownloadsFolder'
        'Setup Log Files'
        'Update Cleanup'
        'Windows ESD installation files'
        'Windows Upgrade Log Files'
    )

    try {
        Write-Host -ForegroundColor 'Green' '[Disk Clean-up] Running ...'
        Set-DiskCleanupProfile -Number 1000 -ExcludeCategories $ExcludeCategories
        $CleanMgrExe = 'cleanmgr.exe'
        $CleanMgrArgs = '/sagerun:1000'
        $CleanMgr = Start-Process -FilePath $CleanMgrExe -ArgumentList $CleanMgrArgs -Wait -PassThru -ErrorAction 'Stop'
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    } finally {
        Remove-DiskCleanupProfile -Number 1000
    }

    if ($CleanMgr.ExitCode -ne 0) {
        $ExcMsg = "${CleanMgrExe} exited with non-zero exit code: $($CleanMgr.ExitCode)"
        $ErrExc = New-Object -TypeName 'Exception' -ArgumentList $ExcMsg
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'NativeCommandFailed', $ErrCat, "${CleanMgrExe} ${CleanMgrArgs}"
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}

Function Invoke-ShutdownCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if (!$PSCmdlet.ShouldProcess('Shutdown clean-up', 'Invoke')) { return }

    $RegKeysToRemove = @(
        # Network list
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\NetworkList\Nla\*'
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles\*'
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\*'

        # Settings
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\ApplicationFrame\Positions\windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel'
        'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\windows.immersivecontrolpanel_cw5n1h2txyewy\ApplicationFrame\windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel'

        # Sysinternals
        'HKCU:\Software\Sysinternals'
    )

    Write-Host -ForegroundColor 'Green' '[Shutdown clean-up] Clearing registry keys ...'
    foreach ($RegKey in $RegKeysToRemove) {
        try {
            Remove-Item -Path $RegKey -Recurse -ErrorAction 'Stop'
        } catch {
            $ErrRec = $PSItem
            switch -Regex ($ErrRec.FullyQualifiedErrorId) {
                '^PathNotFound,' { $Error.RemoveAt(0) }
                default { $PSCmdlet.WriteError($ErrRec) }
            }
        }
    }

    Write-Host -ForegroundColor 'Green' '[Shutdown clean-up] Clearing PowerShell history ...'
    if (Get-Command -Name 'Get-PSReadLineOption' -ErrorAction 'Ignore') {
        $PSReadLineOptions = Get-PSReadLineOption

        if ($PSReadLineOptions.HistorySavePath) {
            try {
                Remove-Item -LiteralPath $PSReadLineOptions.HistorySavePath -ErrorAction 'Stop'
            } catch {
                $ErrRec = $PSItem
                switch -Regex ($ErrRec.FullyQualifiedErrorId) {
                    '^PathNotFound,' { $Error.RemoveAt(0) }
                    default { $PSCmdlet.WriteError($ErrRec) }
                }
            }
        }
    }

    Clear-History
}

Function Optimize-DotNetFramework2x {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!$Script:DotNet20Present) {
        Write-Host -ForegroundColor 'Yellow' '[.NET Framework 2.x] Skipping as not installed.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('.NET Framework 2.x settings', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[.NET Framework 2.x] Applying settings ...'

    # Enable strong cryptography
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Type 'DWord' -Value 1
    if ($Script:Wow64Present) {
        Set-RegistryValue -LiteralPath 'HKLM:\Software\WOW6432Node\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Type 'DWord' -Value 1
    }

    # Let OS choose protocols
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Type 'DWord' -Value 1
    if ($Script:Wow64Present) {
        Set-RegistryValue -LiteralPath 'HKLM:\Software\WOW6432Node\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Type 'DWord' -Value 1
    }

    if ([Environment]::Is64BitOperatingSystem) {
        Invoke-NgenTasks -Version '2.x' -Bitness '64-bit'
        if ($Script:Wow64Present) {
            Invoke-NgenTasks -Version '2.x' -Bitness '32-bit'
        }
    } else {
        Invoke-NgenTasks -Version '2.x' -Bitness '32-bit'
    }
}

Function Optimize-DotNetFramework4x {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!$Script:DotNet40Present) {
        Write-Host -ForegroundColor 'Yellow' '[.NET Framework 4.x] Skipping as not installed.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('.NET Framework 4.x settings', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[.NET Framework 4.x] Applying settings ...'

    # Enable strong cryptography
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Type 'DWord' -Value 1
    if ($Script:Wow64Present) {
        Set-RegistryValue -LiteralPath 'HKLM:\Software\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Type 'DWord' -Value 1
    }

    # Let OS choose protocols
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Type 'DWord' -Value 1
    if ($Script:Wow64Present) {
        Set-RegistryValue -LiteralPath 'HKLM:\Software\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Type 'DWord' -Value 1
    }

    if ([Environment]::Is64BitOperatingSystem) {
        Invoke-NgenTasks -Version '4.x' -Bitness '64-bit'
        if ($Script:Wow64Present) {
            Invoke-NgenTasks -Version '4.x' -Bitness '32-bit'
        }
    } else {
        Invoke-NgenTasks -Version '4.x' -Bitness '32-bit'
    }
}

Function Optimize-Microsoft365 {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if ($Script:WindowsServerCore) {
        Write-Host -ForegroundColor 'Yellow' '[Microsoft 365] Skipping as unsupported on Windows Server Core.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('Microsoft 365 settings', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[Microsoft 365] Applying settings ...'

    # Disable automatic updates
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\Office\ClickToRun\Configuration' -Name 'UpdatesEnabled' -Type 'String' -Value 'False'
}

Function Optimize-PowerShell {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host -ForegroundColor 'Yellow' '[PowerShell] Skipping as version is not at least 5.0.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('PowerShell settings', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[PowerShell] Installing NuGet package provider ...'
    if (Get-Command -Name 'Install-PackageProvider' -ErrorAction 'Ignore') {
        $null = Install-PackageProvider -Name 'NuGet' -Force
    } else {
        # Older versions of PowerShellGet lack the `Install-PackageProvider`
        # command. They will try to download the NuGet package provider on
        # calling `Install-Module` but the manifest specifies a dead URL. The
        # workaround is to manually retrieve the required binary and place it
        # where the module expects.
        $ProvidersPath = Join-Path -Path $Env:ProgramFiles -ChildPath 'PackageManagement\ProviderAssemblies'
        $NuGetPath = Join-Path -Path $ProvidersPath -ChildPath 'nuget-anycpu.exe'
        $NuGetUrl = 'https://oneget.org/nuget-anycpu-2.8.5.127.exe'

        if (!(Test-Path -LiteralPath $NuGetPath -PathType 'Leaf')) {
            if (!(Test-Path -LiteralPath $ProvidersPath -PathType 'Container')) {
                try {
                    $null = New-Item -Path $ProvidersPath -ItemType 'Directory' -ErrorAction 'Stop'
                } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
            }

            # Disabling progress output substantially improves performance
            $ProgressPreferenceOriginal = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                $null = Invoke-WebRequest -Uri $NuGetUrl -OutFile $NuGetPath -UseBasicParsing -ErrorAction 'Stop'
            } catch {
                $PSCmdlet.ThrowTerminatingError($PSItem)
            } finally {
                $ProgressPreference = $ProgressPreferenceOriginal
            }

            # There's some caching of package providers and I've yet to find a
            # way to invalidate it so we request the user restart the session.
            if (Get-Module -Name 'PowerShellGet' -Verbose:$false) {
                Write-Host -ForegroundColor 'Cyan' '[PowerShell] You must restart PowerShell to complete NuGet package provider installation.'
                Write-Host -ForegroundColor 'Cyan' '             Re-run this script afterwards to continue initial PowerShell configuration.'
                return
            }
        }
    }

    $PSGallery = Get-PSRepository -Name 'PSGallery'
    if ($PSGallery.InstallationPolicy -ne 'Trusted') {
        Write-Host -ForegroundColor 'Green' '[PowerShell] Setting PSGallery repository to trusted ...'
        $null = Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
    }

    Write-Host -ForegroundColor 'Green' '[PowerShell] Checking PowerShellGet module ...'
    $PSGetOutdated = $true
    $PSGetLoaded = Get-Module -Name 'PowerShellGet' -Verbose:$false | Sort-Object -Property 'Version' -Descending | Select-Object -First 1
    if ($PSGetLoaded) {
        $PSGetLatest = Find-Module -Name 'PowerShellGet'
        if ($PSGetLoaded.Version -ge $PSGetLatest.Version) {
            $PSGetOutdated = $false
        }
    }

    if ($PSGetOutdated) {
        Write-Host -ForegroundColor 'Green' '[PowerShell] Updating PowerShellGet module ...'
        Install-Module -Name 'PowerShellGet' -Force
        Import-Module -Name 'PowerShellGet' -Force -Verbose:$false
        $PSGetImported = Get-Module -Name 'PowerShellGet' -Verbose:$false | Sort-Object -Property 'Version' -Descending | Select-Object -First 1

        # PowerShellGet loads various .NET types, and types can't be unloaded
        # (at least not easily). That can be problematic as when loading a new
        # version of PowerShellGet into a session which has already imported an
        # earlier version, some types may have been updated but cannot replace
        # the previously loaded types. The solution is to restart PowerShell so
        # we have a new session which isn't "polluted" by an earlier import.
        if ($PSGetLoaded.Version -ne $PSGetImported.Version) {
            Write-Host -ForegroundColor 'Cyan' '[PowerShell] You must restart PowerShell to complete PowerShellGet module installation.'
            Write-Host -ForegroundColor 'Cyan' '             Re-run this script afterwards to continue initial PowerShell configuration.'
            return
        }
    }

    Write-Host -ForegroundColor 'Green' '[PowerShell] Determining modules to update ...'
    $Modules = 'PSReadLine', 'PSWinGlue', 'PSWinVitals', 'PSWindowsUpdate', 'SpeculationControl'
    $ModulesLatest = Find-Module -Name $Modules -Repository 'PSGallery'
    $ModulesInstall = New-Object -TypeName 'Collections.Generic.List[String]'
    $PSReadLineOutdated = $false

    foreach ($ModuleLatest in $ModulesLatest) {
        $ModuleCurrent = Get-Module -Name $ModuleLatest.Name -ListAvailable -Verbose:$false | Sort-Object -Property 'Version' -Descending | Select-Object -First 1
        if ($ModuleCurrent -and $ModuleCurrent.Version -ge $ModuleLatest.Version) { continue }

        if ($ModuleLatest.Name -eq 'PSReadLine') {
            $PSReadLineOutdated = $true
        } else {
            $ModulesInstall.Add($ModuleLatest.Name)
        }
    }

    if ($ModulesInstall.Count -ne 0) {
        Write-Host -ForegroundColor 'Green' '[PowerShell] Updating modules ...'
        foreach ($Module in $ModulesInstall) {
            Write-Host -ForegroundColor 'Gray' "[|-Module] ${Module}"
            $null = Install-Module -Name $Module -Force
        }
    }

    if (Get-Command -Name 'Uninstall-ObsoleteModule' -ErrorAction 'Ignore') {
        Write-Host -ForegroundColor 'Green' '[PowerShell] Uninstalling obsolete modules ...'
        Uninstall-ObsoleteModule
    } else {
        Write-Warning -Message '[PowerShell] Unable to uninstall obsolete modules as Uninstall-ObsoleteModule function not found.'
    }

    if ($PSReadLineOutdated) {
        Write-Host -ForegroundColor 'Cyan' '[PowerShell] To update PSReadLine run the following from an elevated Command Prompt:'
        Write-Host -ForegroundColor 'Cyan' '             powershell -NoProfile -NonInteractive -Command "Install-Module -Name PSReadLine -Force"'
    }
}

Function Optimize-SystemRestore {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if ($Script:WindowsProductType -ne 1) {
        Write-Host -ForegroundColor 'Yellow' '[System Restore] Skipping as unsupported on Windows Server.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('System Restore settings', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[System Restore] Applying settings ...'
    Disable-ComputerRestore -Drive "${Env:SystemDrive}\"
}

Function Optimize-WindowsDefender {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    $MpCmdRunExe = Join-Path -Path $Env:ProgramFiles -ChildPath 'Windows Defender\MpCmdRun.exe'
    if (!(Test-Path -LiteralPath $MpCmdRunExe -PathType 'Leaf')) {
        Write-Host -ForegroundColor 'Yellow' '[Windows Defender] Skipping as unable to find MpCmdRun.exe.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('Windows Defender settings', 'Optimize')) { return }

    if (Get-Command -Name 'Get-MpComputerStatus' -ErrorAction 'Ignore') {
        try {
            $MpStatus = Get-MpComputerStatus -ErrorAction 'Stop'
            if ($MpStatus.IsTamperProtected) {
                Write-Host -ForegroundColor 'Yellow' '[Windows Defender] Skipping as tamper protection is enabled.'
                return
            }
        } catch [Microsoft.Management.Infrastructure.CimException] {
            $ErrRec = $PSItem
            switch -Regex ($ErrRec.FullyQualifiedErrorId) {
                '^MI RESULT 16,' { $MpError = 'MI_RESULT_METHOD_NOT_AVAILABLE' }
                '^HRESULT 0x800106ba,' { $MpError = 'RPC_S_SERVER_UNAVAILABLE' }
                default { $PSCmdlet.ThrowTerminatingError($ErrRec) }
            }

            Write-Host -ForegroundColor 'Yellow' "[Windows Defender] Unable to query status as Get-MpComputerStatus returned: ${MpError}"
        }
    }

    Write-Host -ForegroundColor 'Green' '[Windows Defender] Applying settings ...'

    # Disable Defender antivirus
    # Windows 10 v1809 / Server 2019 or earlier
    if ($Script:WindowsBuildNumber -le 17763) {
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender' -Name 'DisableAntiSpyware' -Type 'DWord' -Value 1
    }

    # Disable real-time protection
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableRealtimeMonitoring' -Type 'DWord' -Value 1

    # Disable signature update before scheduled scan
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Scan' -Name 'CheckForSignaturesBeforeRunningScan' -Type 'DWord' -Value 0

    # Disable Microsoft Active Protection Service
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Spynet' -Name 'SpynetReporting' -Type 'DWord' -Value 0

    # Disable submission of file samples
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Spynet' -Name 'SubmitSamplesConsent' -Type 'DWord' -Value 2

    # Windows 8 / Server 2012 or later
    if ($Script:WindowsBuildNumber -ge 9200) {
        # Disable behaviour monitoring
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableBehaviorMonitoring' -Type 'DWord' -Value 1

        # Disable downloaded files and attachments scanning
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableIOAVProtection' -Type 'DWord' -Value 1

        # Disable file and program activity monitoring
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableOnAccessProtection' -Type 'DWord' -Value 1

        # Disable scheduled remediation scans
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Remediation' -Name 'Scan_ScheduleDay' -Type 'DWord' -Value 8

        # Disable scheduled scans
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Scan' -Name 'ScheduleDay' -Type 'DWord' -Value 8

        # Disable scan on signature update
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'DisableScanOnUpdate' -Type 'DWord' -Value 1

        # Disable startup update on absent malware engine
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'DisableUpdateOnStartupWithoutEngine' -Type 'DWord' -Value 1

        # Disable scheduled signature updates
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'ScheduleDay' -Type 'DWord' -Value 8

        # Disable signature update on startup
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'UpdateOnStartUp' -Type 'DWord' -Value 0

        # Disable recent activity and scan results notifications
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\Windows Defender Security Center\Virus and threat protection' -Name 'SummaryNotificationDisabled' -Type 'DWord' -Value 1
    }

    Write-Host -ForegroundColor 'Green' '[Windows Defender] Removing definitions ...'
    $MpCmdRunArgs = '-RemoveDefinitions', '-All'
    & $MpCmdRunExe @MpCmdRunArgs
    if ($LASTEXITCODE -ne 0) {
        $ExcMsg = "${MpCmdRunExe} exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = New-Object -TypeName 'Exception' -ArgumentList $ExcMsg
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'NativeCommandFailed', $ErrCat, "${MpCmdRunExe} $($MpCmdRunArgs -join ' ')"
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}

Function Optimize-WindowsPower {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if (!$PSCmdlet.ShouldProcess('Windows power settings', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[Windows] Applying power settings ...'
    $PowerCfgExe = 'powercfg.exe'
    $PowerCfgChanges = 'monitor-timeout-ac', 'disk-timeout-ac', 'standby-timeout-ac', 'hibernate-timeout-ac'
    foreach ($PowerCfgChange in $PowerCfgChanges) {
        try {
            $PowerCfgArgs = '/Change', $PowerCfgChange, '0'
            $PowerCfg = Start-Process -FilePath $PowerCfgExe -ArgumentList $PowerCfgArgs -NoNewWindow -Wait -PassThru -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

        if ($PowerCfg.ExitCode -ne 0) {
            $ExcMsg = "${PowerCfgExe} exited with non-zero exit code: $($PowerCfg.ExitCode)"
            $ErrExc = New-Object -TypeName 'Exception' -ArgumentList $ExcMsg
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'NativeCommandFailed', $ErrCat, "${PowerCfgExe} $($PowerCfgArgs -join ' ')"
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

Function Optimize-WindowsSecurity {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!$PSCmdlet.ShouldProcess('Windows security settings', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[Windows] Applying security policy ...'
    $SecEditExe = 'SecEdit.exe'
    $SecEditDb = Join-Path -Path $Env:windir -ChildPath 'Security\Local.sdb'
    $SecEditCfg = Join-Path -Path $Env:windir -ChildPath 'Temp\SecPol.cfg'

    Write-Host -ForegroundColor 'Gray' '[|-SecEdit] - Exporting current security policy ...'
    $SecEditArgs = '/export', '/cfg', $SecEditCfg, '/quiet'
    & $SecEditExe @SecEditArgs
    if ($LASTEXITCODE -ne 0) {
        $ExcMsg = "${SecEditExe} exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = New-Object -TypeName 'Exception' -ArgumentList $ExcMsg
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'NativeCommandFailed', $ErrCat, "${SecEditExe} $($SecEditArgs -join ' ')"
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    Write-Host -ForegroundColor 'Gray' '[|-SecEdit] - Updating security policy template ...'
    $SecPol = Get-Content -LiteralPath $SecEditCfg | ForEach-Object {
        $PSItem -replace '^(MinimumPasswordAge) *= *.+', '$1 = 0' `
            -replace '^(MaximumPasswordAge) *= *.+', '$1 = -1' `
            -replace '^(PasswordComplexity) *= *.+', '$1 = 0'
    }
    $SecPol | Set-Content -LiteralPath $SecEditCfg -Encoding 'Unicode'

    Write-Host -ForegroundColor 'Gray' '[|-SecEdit] - Applying updated security policy ...'
    $SecEditArgs = '/configure', '/db', $SecEditDb, '/cfg', $SecEditCfg, '/quiet'
    & $SecEditExe @SecEditArgs
    if ($LASTEXITCODE -ne 0) {
        $ExcMsg = "${SecEditExe} exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = New-Object -TypeName 'Exception' -ArgumentList $ExcMsg
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'NativeCommandFailed', $ErrCat, "${SecEditExe} $($SecEditArgs -join ' ')"
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        Write-Host -ForegroundColor 'Gray' '[|-SecEdit] - Cleaning-up ...'
        Remove-Item -LiteralPath $SecEditCfg -ErrorAction 'Stop'
    } catch { $PSCmdlet.WriteError($PSItem) }

    Write-Host -ForegroundColor 'Green' '[Windows] Applying security settings ...'

    # Enable SSL/TLS protocols where not enabled by default
    $EnableTls11 = $false
    $EnableTls12 = $false
    if ($Script:WindowsProductType -ne 1 -and ($Script:WindowsBuildNumber -ge 6001 -and $Script:WindowsBuildNumber -le 6003)) {
        # Windows Server 2008
        $EnableTls11 = $true
        $EnableTls12 = $true
    } elseif ($Script:WindowsBuildNumber -ge 7600 -and $Script:WindowsBuildNumber -le 7601) {
        # Windows 7 / Server 2008 R2
        $EnableTls11 = $true
        $EnableTls12 = $true
    }

    # Enable TLS 1.1
    if ($EnableTls11) {
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SChannel\Protocols\TLS 1.1\Client' -Name 'DisabledByDefault' -Type 'DWord' -Value 0
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SChannel\Protocols\TLS 1.1\Client' -Name 'Enabled' -Type 'DWord' -Value 1
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SChannel\Protocols\TLS 1.1\Server' -Name 'DisabledByDefault' -Type 'DWord' -Value 0
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SChannel\Protocols\TLS 1.1\Server' -Name 'Enabled' -Type 'DWord' -Value 1
    }

    # Enable TLS 1.2
    if ($EnableTls12) {
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SChannel\Protocols\TLS 1.2\Client' -Name 'DisabledByDefault' -Type 'DWord' -Value 0
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SChannel\Protocols\TLS 1.2\Client' -Name 'Enabled' -Type 'DWord' -Value 1
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SChannel\Protocols\TLS 1.2\Server' -Name 'DisabledByDefault' -Type 'DWord' -Value 0
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SChannel\Protocols\TLS 1.2\Server' -Name 'Enabled' -Type 'DWord' -Value 1
    }

    # Set WinHTTP default protocols to: TLS 1.0, TLS 1.1, TLS 1.2
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Type 'DWord' -Value 2688
    if ($Script:Wow64Present) {
        Set-RegistryValue -LiteralPath 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Type 'DWord' -Value 2688
    }
}

Function Optimize-WindowsSettingsComputer {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if (!$PSCmdlet.ShouldProcess('Windows settings (machine)', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[Windows] Applying computer settings ...'

    # Disable Network Location Wizard
    if (!$Script:WindowsServerCore) {
        Set-RegistryValue -LiteralPath 'HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff'
    }

    # Disable Shutdown Event Tracker
    if (!$Script:WindowsServerCore) {
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows NT\Reliability' -Name 'ShutdownReasonOn' -Type 'DWord' -Value 0
    }

    # Do not display Server Manager automatically at logon
    if ($Script:WindowsProductType -ne 1) {
        # The Server Manager UI only disables at the user scope
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows\Server\ServerManager' -Name 'DoNotOpenAtLogon' -Type 'DWord' -Value 1
    }

    # Windows 7 / Server 2008 R2 or later
    if ($Script:WindowsBuildNumber -ge 7600) {
        # Disable automatic maintenance
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' -Name 'MaintenanceDisabled' -Type 'DWord' -Value 1
    }

    # Windows 8 / Server 2012 (non-Core) or later
    if ($Script:WindowsBuildNumber -ge 9200 -and !$Script:WindowsServerCore) {
        # Disable Explorer SmartScreen
        # Suppressing the warning disabled via the Settings UI is non-trivial
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name 'EnableSmartScreen' -Type 'DWord' -Value 0
    }

    # Windows 10 v1507 / Server 2016 or later
    if ($Script:WindowsBuildNumber -ge 10240) {
        # Only send security telemetry
        # The Settings UI doesn't support the Security telemetry level
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Type 'DWord' -Value 0
    }
}

Function Optimize-WindowsSettingsUser {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if ($Script:WindowsServerCore) {
        Write-Host -ForegroundColor 'Yellow' '[Windows] Skipping user settings as not applicable to Windows Server Core.'
        return
    }

    if (!$PSCmdlet.ShouldProcess('Windows settings (user)', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[Windows] Applying user settings ...'

    # Remove Recycle Bin desktop icon
    Set-RegistryValue -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Type 'DWord' -Value 1
    # Windows Vista / Server 2008 or earlier
    if ($Script:WindowsBuildNumber -le 6003) {
        Set-RegistryValue -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Type 'DWord' -Value 1
    }

    # Windows 8 / Server 2012 or later
    if ($Script:WindowsBuildNumber -ge 9200) {
        # Disable startup programs launch delay
        Set-RegistryValue -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Type 'DWord' -Value 0
    }

    # Remove volume control icon
    $AudioSrv = Get-Service -Name 'AudioSrv' -ErrorAction 'Ignore'
    if ($AudioSrv -and $AudioSrv.Status -eq 'Stopped') {
        # Unclear how the equivalent UI setting is set
        Set-RegistryValue -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCAVolume' -Type 'DWord' -Value 1
    }
}

Function Optimize-WindowsUpdate {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param()

    if (!$PSCmdlet.ShouldProcess('Windows Update settings', 'Optimize')) { return }

    Write-Host -ForegroundColor 'Green' '[Windows Update] Applying settings ...'

    # Disable automatic updates
    # Unclear if the UI setting is supported on all Windows releases
    Set-RegistryValue -LiteralPath 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Type 'DWord' -Value 1

    # Windows 8.1 / Server 2012 R2 or earlier
    if ($Script:WindowsBuildNumber -le 9600) {
        # Enable recommended updates
        Set-RegistryValue -LiteralPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'IncludeRecommendedUpdates' -Type 'DWord' -Value 1
    }

    # Disable MSRT updates
    Set-RegistryValue -LiteralPath 'HKCU:\Software\Policies\Microsoft\MRT' -Name 'DontOfferThroughWUAU' -Type 'DWord' -Value 1

    try {
        $ServiceManager = $null
        $ServiceRegistration = $null

        Write-Host -ForegroundColor 'Green' '[Windows Update] Registering Microsoft Update ...'
        $ServiceFlags = 7 # asfAllowPendingRegistration + asfAllowOnlineRegistration + asfRegisterServiceWithAU
        $ServiceManager = New-Object -ComObject 'Microsoft.Update.ServiceManager'
        $ServiceRegistration = $ServiceManager.AddService2('7971f918-a847-4430-9279-4a52d1efe18d', $ServiceFlags, '')
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    } finally {
        if ($ServiceRegistration) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($ServiceRegistration) }
        if ($ServiceManager) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($ServiceManager) }
    }
}

#region Utilities

Function Get-WindowsInfo {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # The implicit import of the `CimCmdlets` module that may occur below
    # triggers several "What if" outputs under Windows PowerShell, even though
    # `Get-CimInstance` doesn't support `-WhatIf`. As this cmdlet doesn't
    # modify any state we temporarily disable `WhatIf` mode.
    try {
        $WhatIfOriginal = $WhatIfPreference
        $WhatIfPreference = $false

        $Win32OpSys = Get-CimInstance -Class 'Win32_OperatingSystem' -ErrorAction 'Stop' -Verbose:$false
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    } finally {
        $WhatIfPreference = $WhatIfOriginal
    }

    $Script:WindowsBuildNumber = [UInt32]$Win32OpSys.BuildNumber
    $Script:WindowsProductType = $Win32OpSys.ProductType

    if (Test-Path -LiteralPath 'HKLM:\Software\WOW6432Node\Microsoft\Windows NT\CurrentVersion' -PathType 'Container') {
        $Script:Wow64Present = $true
    } else {
        $Script:Wow64Present = $false
    }

    $ExplorerPath = Join-Path -Path $Env:windir -ChildPath 'explorer.exe'
    if (Test-Path -LiteralPath $ExplorerPath -PathType 'Leaf') {
        $Script:WindowsServerCore = $false
    } else {
        $Script:WindowsServerCore = $true
    }
}

Function Invoke-NgenTasks {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('2.x', '4.x')]
        [String]$Version,

        [Parameter(Mandatory)]
        [ValidateSet('32-bit', '64-bit')]
        [String]$Bitness
    )

    switch ($Version) {
        '2.x' { $FullVersion = 'v2.0.50727' }
        '4.x' { $FullVersion = 'v4.0.30319' }
    }

    switch ($Bitness) {
        '32-bit' { $Framework = 'Framework' }
        '64-bit' { $Framework = 'Framework64' }
    }

    $NgenExe = Join-Path -Path $Env:windir -ChildPath "Microsoft.NET\${Framework}\${FullVersion}\ngen.exe"
    if (!(Test-Path -LiteralPath $NgenExe -PathType 'Leaf')) {
        Write-Warning -Message "[.NET Framework ${Version}] Unable to locate ${Bitness} executable: ngen.exe"
        return
    }

    Write-Host -ForegroundColor 'Green' "[.NET Framework ${Version}] Running ${Bitness} queued compilation jobs ..."
    $NgenArgs = 'executeQueuedItems', '/nologo', '/silent'
    & $NgenExe @NgenArgs
    if ($LASTEXITCODE -ne 0) {
        $ExcMsg = "${NgenExe} exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = New-Object -TypeName 'Exception' -ArgumentList $ExcMsg
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'NativeCommandFailed', $ErrCat, "${NgenExe} $($NgenArgs -join ' ')"
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}

Function Remove-DiskCleanupProfile {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [ValidateRange(0, 9999)]
        [UInt16]$Number
    )

    $BasePath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $ValueName = 'StateFlags{0:D4}' -f $Number

    $Categories = Get-ChildItem -LiteralPath $BasePath -ErrorAction 'Ignore'
    foreach ($Category in $Categories) {
        if ($Category.Property -contains $ValueName) {
            $RegPath = Join-Path -Path $BasePath -ChildPath $Category.PSChildName
            Remove-ItemProperty -LiteralPath $RegPath -Name $ValueName
        }
    }
}

Function Set-DiskCleanupProfile {
    <#
        Known categories:
        - Active Setup Temp Folders
        - BranchCache
        - Content Indexer Cleaner
        - D3D Shader Cache
        - Delivery Optimization Files
        - Device Driver Packages
        - Diagnostic Data Viewer database files
        - Downloaded Program Files
        - DownloadsFolder
        - Feedback Hub Archive log files
        - GameNewsFiles
        - GameStatisticsFiles
        - GameUpdateFiles
        - Internet Cache Files
        - Language Pack
        - Memory Dump Files (XXX)
        - Offline Pages Files
        - Old ChkDsk Files
        - Previous Installations
        - Recycle Bin
        - RetailDemo Offline Content
        - Service Pack Cleanup
        - Setup Log Files
        - System error memory dump files
        - System error minidump files
        - Temporary Files
        - Temporary Setup Files
        - Temporary Sync Files
        - Thumbnail Cache
        - Update Cleanup
        - Upgrade Discarded Files
        - User file versions
        - Windows Defender
        - Windows Error Reporting Archive Files
        - Windows Error Reporting Files
        - Windows Error Reporting Queue Files
        - Windows Error Reporting System Archive Files
        - Windows Error Reporting System Queue Files
        - Windows Error Reporting Temp Files
        - Windows ESD installation files
        - Windows Reset Log Files
        - Windows Upgrade Log Files

        Sourced from:
        - Windows 11 25H2
        - Windows Server 2012 R2 through 2025
    #>

    [CmdletBinding(DefaultParameterSetName = 'OptOut')]
    [OutputType([Void])]
    Param(
        [ValidateRange(0, 9999)]
        [UInt16]$Number,

        [Parameter(ParameterSetName = 'OptOut')]
        [String[]]$ExcludeCategories,

        [Parameter(ParameterSetName = 'OptIn', Mandatory)]
        [String[]]$IncludeCategories
    )

    $BasePath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $ValueName = 'StateFlags{0:D4}' -f $Number

    if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
        $CategoriesParameter = $ExcludeCategories
    } else {
        $CategoriesParameter = $IncludeCategories
    }

    try {
        $BaseKey = Get-Item -LiteralPath $BasePath -ErrorAction 'Stop'
        $ValidCategories = $BaseKey.GetSubKeyNames()
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    $UnknownCategories = New-Object -TypeName 'Collections.Generic.List[String]'
    foreach ($Category in $CategoriesParameter) {
        if ($ValidCategories -notcontains $Category) {
            $UnknownCategories.Add($Category)
        }
    }

    $UnknownCategories.Sort()
    if ($UnknownCategories.Count -ne 0) {
        Write-Warning -Message "Some Disk Clean-up categories will be ignored: $($UnknownCategories.ToArray() -join ', ')"
    }

    if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
        $Categories = $ValidCategories | Where-Object { $CategoriesParameter -notcontains $PSItem }
    } else {
        $Categories = $IncludeCategories
    }

    foreach ($Category in $ValidCategories) {
        $RegPath = Join-Path -Path $BasePath -ChildPath $Category
        $ValueData = 0

        if ($Categories -contains $Category) {
            $ValueData = 2
        }

        Set-RegistryValue -LiteralPath $RegPath -Name $ValueName -Type 'DWord' -Value $ValueData
    }
}

Function Set-RegistryValue {
    [CmdletBinding(DefaultParameterSetName = 'KeyOnly')]
    [OutputType([Void])]
    Param(
        [Parameter(ParameterSetName = 'KeyOnly', Mandatory)]
        [Parameter(ParameterSetName = 'KeyValue', Mandatory)]
        [String]$LiteralPath,

        [Parameter(ParameterSetName = 'KeyValue', Mandatory)]
        [String]$Name,

        [Parameter(ParameterSetName = 'KeyValue', Mandatory)]
        [String]$Type,

        [Parameter(ParameterSetName = 'KeyValue', Mandatory)]
        [String]$Value
    )

    if (!(Test-Path -LiteralPath $LiteralPath -PathType 'Container')) {
        try {
            $null = New-Item -Path $LiteralPath -Force -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }

    if ($PSCmdlet.ParameterSetName -eq 'KeyValue') {
        try {
            Set-ItemProperty @PSBoundParameters -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }
}

Function Test-DotNetPresent {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $ClrVersions = '2.0', '4.0'
    foreach ($ClrVersion in $ClrVersions) {
        $VarName = "DotNet$($ClrVersion -replace '\.')Present"
        switch ($ClrVersion) {
            '2.0' { $RegPath = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v2.0.50727' }
            '4.0' { $RegPath = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full' }
        }

        $RegKey = Get-Item -LiteralPath $RegPath -ErrorAction 'Ignore'
        if ($RegKey -and $RegKey.GetValue('Version')) {
            Set-Variable -Name $VarName -Scope 'Script' -Value $true -WhatIf:$false
        } else {
            Set-Variable -Name $VarName -Scope 'Script' -Value $false -WhatIf:$false
        }
    }
}

#endregion

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $ExcMsg = "$(Split-Path -Path $PSCommandPath -Leaf) is not compatible with PowerShell 6 or later."
    $ErrExc = New-Object -TypeName 'PlatformNotSupportedException' -ArgumentList $ExcMsg
    $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
    $ErrRec = New-Object -TypeName 'Management.Automation.ErrorRecord' -ArgumentList $ErrExc, 'PwshNotSupported', $ErrCat, $null
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

Get-WindowsInfo
Test-DotNetPresent

$Tasks = New-Object -TypeName 'Collections.Specialized.OrderedDictionary'
$Tasks.Add('ComponentStore', @('Invoke-ComponentStoreCleanup'))
$Tasks.Add('DiskCleanup', @('Invoke-DiskCleanup'))
$Tasks.Add('DotNetFramework', @('Optimize-DotNetFramework2x', 'Optimize-DotNetFramework4x'))
$Tasks.Add('Microsoft365', @('Optimize-Microsoft365'))
$Tasks.Add('PowerShell', @('Optimize-PowerShell'))
$Tasks.Add('ShutdownCleanup', @('Invoke-ShutdownCleanup'))
$Tasks.Add('SystemRestore', @('Optimize-SystemRestore'))
$Tasks.Add('WindowsDefender', @('Optimize-WindowsDefender'))
$Tasks.Add('WindowsPower', @('Optimize-WindowsPower'))
$Tasks.Add('WindowsSecurity', @('Optimize-WindowsSecurity'))
$Tasks.Add('WindowsSettings', @('Optimize-WindowsSettingsComputer', 'Optimize-WindowsSettingsUser'))
$Tasks.Add('WindowsUpdate', @('Optimize-WindowsUpdate'))

foreach ($Task in $Tasks.Keys) {
    if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
        if ($ExcludeTasks -contains $Task) { continue }
    } else {
        if ($IncludeTasks -notcontains $Task) { continue }
    }

    foreach ($Function in $Tasks[$Task]) {
        & $Function
    }
}
