[CmdletBinding(DefaultParameterSetName = 'OptOut')]
Param(
    [Parameter(ParameterSetName = 'OptOut')]
    [ValidateSet(
        'DiskCleanup',
        'DotNetFramework',
        'Office365',
        'PowerShell',
        'WindowsComponents',
        'WindowsDefender',
        'WindowsPower',
        'WindowsRestore',
        'WindowsSecurity',
        'WindowsSettingsComputer',
        'WindowsSettingsUser',
        'WindowsUpdate'
    )]
    [String[]]$ExcludeTasks,

    [Parameter(ParameterSetName = 'OptIn', Mandatory = $true)]
    [ValidateSet(
        'DiskCleanup',
        'DotNetFramework',
        'Office365',
        'PowerShell',
        'WindowsComponents',
        'WindowsDefender',
        'WindowsPower',
        'WindowsRestore',
        'WindowsSecurity',
        'WindowsSettingsComputer',
        'WindowsSettingsUser',
        'WindowsUpdate'
    )]
    [String[]]$IncludeTasks
)

Function Optimize-DiskCleanup {
    [CmdletBinding()]
    Param()

    if (!(Get-Command -Name 'cleanmgr.exe' -ErrorAction SilentlyContinue)) {
        Write-Host -ForegroundColor Yellow '[Windows] Skipping Disk Cleanup as unable to find cleanmgr.exe.'
        return
    }


    Write-Host -ForegroundColor Green '[Windows] Running Disk Cleanup ...'
    $ExcludeCategories = @(
        'DownloadsFolder',
        'Setup Log Files',
        'Update Cleanup',
        'Windows ESD installation files',
        'Windows Upgrade Log Files'
    )
    Set-DiskCleanupProfile -Number 1000 -ExcludeCategories $ExcludeCategories
    Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:1000' -Wait
    Remove-DiskCleanupProfile -Number 1000
}

Function Optimize-DotNetFramework {
    [CmdletBinding()]
    Param()

    Test-DotNetPresent

    if ($Script:DotNet20Present) {
        Write-Host -ForegroundColor Green '[.NET Framework] Applying .NET Framework 2.x settings ...'

        # Enable strong cryptography
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        if ($Script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        }

        # Let OS choose protocols
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        if ($Script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        }
    } else {
        Write-Host -ForegroundColor Yellow '[.NET Framework] Skipping .NET Framework 2.x as not installed.'
    }

    if ($Script:DotNet40Present) {
        Write-Host -ForegroundColor Green '[.NET Framework] Applying .NET Framework 4.x settings ...'

        # Enable strong cryptography
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        if ($Script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        }

        # Let OS choose protocols
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        if ($Script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        }
    } else {
        Write-Host -ForegroundColor Yellow '[.NET Framework] Skipping .NET Framework 4.x as not installed.'
    }
}

Function Optimize-Office365 {
    [CmdletBinding()]
    Param()

    if ($Script:WindowsServerCore) {
        Write-Host -ForegroundColor Yellow '[Office 365] Skipping as unsupported on Windows Server Core.'
        return
    }

    Write-Host -ForegroundColor Green '[Office 365] Applying settings ...'

    # Disable automatic updates
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Office\16.0\Common\OfficeUpdate' -Name 'EnableAutomaticUpdates' -Type DWord -Value 0
}

Function Optimize-PowerShell {
    [CmdletBinding()]
    Param()

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host -ForegroundColor Yellow '[PowerShell] Skipping as version is not at least v5.0.'
        return
    }

    Write-Host -ForegroundColor Green '[PowerShell] Installing NuGet package provider ...'
    if (Get-Command -Name 'Install-PackageProvider' -ErrorAction Ignore) {
        $null = Install-PackageProvider -Name NuGet -Force
    } else {
        # Older versions of PowerShellGet lack the Install-PackageProvider
        # command. They will try to download the NuGet package provider on
        # calling Install-Module but the manifest specifies a dead URL. The
        # workaround is to manually retrieve the required binary and place it
        # where the module expects.
        $ProvidersPath = Join-Path -Path $env:ProgramFiles -ChildPath 'PackageManagement\ProviderAssemblies'
        $NuGetPath = Join-Path -Path $ProvidersPath -ChildPath 'nuget-anycpu.exe'
        $NuGetUrl = 'https://oneget.org/nuget-anycpu-2.8.5.127.exe'

        if (!(Test-Path -Path $NuGetPath -PathType Leaf)) {
            if (!(Test-Path -Path $ProvidersPath -PathType Container)) {
                $null = New-Item -Path $ProvidersPath -ItemType Directory
            }

            # Disabling progress output substantially improves performance
            $ProgressPreferenceOriginal = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            $null = Invoke-WebRequest -Uri $NuGetUrl -OutFile $NuGetPath -UseBasicParsing
            $ProgressPreference = $ProgressPreferenceOriginal

            # There's some caching of package providers and I've yet to find a
            # way to invalidate it so we request the user restart the session.
            if (Get-Module -Name PowerShellGet) {
                Write-Host -ForegroundColor Cyan '[PowerShell] You must restart PowerShell to complete NuGet package provider installation.'
                Write-Host -ForegroundColor Cyan '             Re-run this script afterwards to continue initial PowerShell configuration.'
                return
            }
        }
    }

    $PSGallery = Get-PSRepository -Name PSGallery
    if ($PSGallery.InstallationPolicy -ne 'Trusted') {
        Write-Host -ForegroundColor Green '[PowerShell] Setting PSGallery repository to trusted ...'
        $null = Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    Write-Host -ForegroundColor Green '[PowerShell] Checking PowerShellGet module ...'
    $PSGetOutdated = $true
    $PSGetLoaded = Get-Module -Name PowerShellGet | Sort-Object -Property Version -Descending | Select-Object -First 1
    if ($PSGetLoaded) {
        $PSGetLatest = Find-Module -Name PowerShellGet
        if ($PSGetLoaded.Version -ge $PSGetLatest.Version) {
            $PSGetOutdated = $false
        }
    }

    if ($PSGetOutdated) {
        Write-Host -ForegroundColor Green '[PowerShell] Updating PowerShellGet module ...'
        Install-Module -Name PowerShellGet -Force
        Import-Module -Name PowerShellGet -Force
        $PSGetImported = Get-Module -Name PowerShellGet | Sort-Object -Property Version -Descending | Select-Object -First 1

        # PowerShellGet loads various .NET types, and types can't be unloaded
        # (at least not easily). That can be problematic as when loading a new
        # version of PowerShellGet into a session which has already imported an
        # earlier version, some types may have been updated but cannot replace
        # the previously loaded types. The solution is to restart PowerShell so
        # we have a new session which isn't "polluted" by an earlier import.
        if ($PSGetLoaded.Version -ne $PSGetImported.Version) {
            Write-Host -ForegroundColor Cyan '[PowerShell] You must restart PowerShell to complete PowerShellGet module installation.'
            Write-Host -ForegroundColor Cyan '             Re-run this script afterwards to continue initial PowerShell configuration.'
            return
        }
    }

    Write-Host -ForegroundColor Green '[PowerShell] Determining modules to update ...'
    $Modules = 'PSReadLine', 'PSWinGlue', 'PSWinVitals', 'PSWindowsUpdate', 'SpeculationControl'
    $ModulesLatest = Find-Module -Name $Modules -Repository PSGallery
    $ModulesInstall = [Collections.ArrayList]::new()

    foreach ($ModuleLatest in $ModulesLatest) {
        $ModuleCurrent = Get-Module -Name $ModuleLatest.Name -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        if ($ModuleCurrent.Version -ge $ModuleLatest.Version) {
            continue
        }

        if ($ModuleLatest.Name -eq 'PSReadLine') {
            $PSReadLineOutdated = $true
        } else {
            $null = $ModulesInstall.Add($ModuleLatest.Name)
        }
    }

    if ($ModulesInstall.Count -ne 0) {
        Write-Host -ForegroundColor Green '[PowerShell] Updating modules ...'
        foreach ($Module in $ModulesInstall) {
            Write-Host -ForegroundColor Gray ('[PowerShell] - {0}' -f $Module)
            $null = Install-Module -Name $Module -Force
        }
    }

    if ($PSReadLineOutdated) {
        Write-Host -ForegroundColor Cyan '[PowerShell] To update PSReadLine run the following from an elevated Command Prompt:'
        Write-Host -ForegroundColor Cyan '             powershell -NoProfile -NonInteractive -Command "Install-Module -Name PSReadLine -Force"'
    }
}

Function Optimize-WindowsComponents {
    [CmdletBinding()]
    Param()

    if ($Script:WindowsBuildNumber -ge 9200) {
        Write-Host -ForegroundColor Green -NoNewline '[Windows] Performing component store clean-up ...'
        & dism.exe /Online /Cleanup-Image /StartComponentCleanup
        Write-Host
        return
    }

    if (!(Get-Command -Name 'cleanmgr.exe' -ErrorAction SilentlyContinue)) {
        Write-Host -ForegroundColor Yellow '[Windows] Skipping component store clean-up as unable to find cleanmgr.exe.'
        return
    }

    Write-Host -ForegroundColor Green '[Windows] Running Disk Cleanup with Update Cleanup task ...'
    Set-DiskCleanupProfile -Number 1000 -IncludeCategories 'Update Cleanup'
    Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:1000' -Wait
    Remove-DiskCleanupProfile -Number 1000
}

Function Optimize-WindowsDefender {
    [CmdletBinding()]
    Param()

    $MpCmdRun = Join-Path -Path $env:ProgramFiles -ChildPath 'Windows Defender\MpCmdRun.exe'
    if (!(Test-Path -Path $MpCmdRun -PathType Leaf)) {
        Write-Host -ForegroundColor Yellow '[Windows] Skipping Defender as unable to find MpCmdRun.exe.'
        return
    }

    if (Get-Command -Name 'Get-MpComputerStatus' -ErrorAction SilentlyContinue) {
        try {
            $MpStatus = Get-MpComputerStatus -ErrorAction Stop
            if ($MpStatus.IsTamperProtected) {
                Write-Host -ForegroundColor Yellow '[Windows] Skipping Defender as tamper protection is enabled.'
                return
            }
        } catch [Microsoft.Management.Infrastructure.CimException] {
            # The extrinsic Method could not be executed
            if ($_.FullyQualifiedErrorId -match '^MI RESULT 16,') {
                Write-Host -ForegroundColor Yellow '[Windows] Unable to query Defender status as Get-MpComputerStatus returned: MI_RESULT_METHOD_NOT_AVAILABLE'
            } else {
                Write-Error -Message $_
                return
            }
        }
    }

    Write-Host -ForegroundColor Green '[Windows] Applying Defender settings ...'

    # Disable Defender antivirus
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender' -Name 'DisableAntiSpyware' -Type DWord -Value 1

    # Disable real-time protection
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableRealtimeMonitoring' -Type DWord -Value 1

    # Disable signature update before scheduled scan
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Scan' -Name 'CheckForSignaturesBeforeRunningScan' -Type DWord -Value 0

    # Disable Microsoft Active Protection Service
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Spynet' -Name 'SpynetReporting' -Type DWord -Value 0

    # Disable submission of file samples
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Spynet' -Name 'SubmitSamplesConsent' -Type DWord -Value 2

    if ($Script:WindowsBuildNumber -ge 9200) {
        # Disable behaviour monitoring
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableBehaviorMonitoring' -Type DWord -Value 1

        # Disable downloaded files and attachments scanning
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableIOAVProtection' -Type DWord -Value 1

        # Disable file and program activity monitoring
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableOnAccessProtection' -Type DWord -Value 1

        # Disable scheduled remediation scans
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Remediation' -Name 'Scan_ScheduleDay' -Type DWord -Value 8

        # Disable scheduled scans
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Scan' -Name 'ScheduleDay' -Type DWord -Value 8

        # Disable scan on signature update
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'DisableScanOnUpdate' -Type DWord -Value 1

        # Disable startup update on absent malware engine
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'DisableUpdateOnStartupWithoutEngine' -Type DWord -Value 1

        # Disable scheduled signature updates
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'ScheduleDay' -Type DWord -Value 8

        # Disable signature update on startup
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'UpdateOnStartUp' -Type DWord -Value 0
    }

    # Disable recent activity and scan results notifications
    if ($Script:WindowsBuildNumber -ge 9200) {
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows Defender Security Center\Virus and threat protection' -Name 'SummaryNotificationDisabled' -Type DWord -Value 1
    }

    Write-Host -ForegroundColor Green -NoNewline '[Windows] Removing Defender definitions ...'
    & $MpCmdRun -RemoveDefinitions -All
    Write-Host
}

Function Optimize-WindowsPower {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows] Applying power settings ...'
    & PowerCfg /Change monitor-timeout-ac 0
    & PowerCfg /Change disk-timeout-ac 0
    & PowerCfg /Change standby-timeout-ac 0
    & PowerCfg /Change hibernate-timeout-ac 0
}

Function Optimize-WindowsRestore {
    [CmdletBinding()]
    Param()

    if ($Script:WindowsProductType -ne 1) {
        Write-Host -ForegroundColor Yellow '[Windows] Skipping System Restore as unsupported on Windows Server.'
        return
    }

    Write-Host -ForegroundColor Green '[Windows] Applying System Restore settings ...'
    Disable-ComputerRestore -Drive $env:SystemDrive
}

Function Optimize-WindowsSecurity {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows] Applying security policy ...'
    $SecEditDb = Join-Path -Path $env:windir -ChildPath 'Security\Local.sdb'
    $SecEditCfg = Join-Path -Path $env:windir -ChildPath 'Temp\SecPol.cfg'

    Write-Host -ForegroundColor Gray '[SecEdit] - Exporting current security policy ...'
    & SecEdit.exe /export /cfg $SecEditCfg /quiet

    Write-Host -ForegroundColor Gray '[SecEdit] - Updating security policy template ...'
    $SecPol = Get-Content -Path $SecEditCfg | ForEach-Object {
        $_ -replace '^(MinimumPasswordAge) *= *.+', '$1 = 0' `
            -replace '^(MaximumPasswordAge) *= *.+', '$1 = -1' `
            -replace '^(PasswordComplexity) *= *.+', '$1 = 0'
    }
    $SecPol | Set-Content -Path $SecEditCfg

    Write-Host -ForegroundColor Gray '[SecEdit] - Applying updated security policy ...'
    & SecEdit.exe /configure /db $SecEditDb /cfg $SecEditCfg /quiet

    Write-Host -ForegroundColor Gray '[SecEdit] - Cleaning-up ...'
    Remove-Item $SecEditCfg

    Write-Host -ForegroundColor Green '[Windows] Applying security settings ...'

    # Set WinHTTP default protocols to: TLS 1.0, TLS 1.1, TLS 1.2
    Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Type DWord -Value 2688
    if ($Script:Wow64Present) {
        Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Type DWord -Value 2688
    }
}

Function Optimize-WindowsSettingsComputer {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows] Applying computer settings ...'

    # Disable Shutdown Event Tracker
    if (!$Script:WindowsServerCore) {
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Reliability' -Name 'ShutdownReasonOn' -Type DWord -Value 0
    }

    # Do not display Server Manager automatically at logon
    if ($Script:WindowsProductType -ne 1) {
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Server\ServerManager' -Name 'DoNotOpenAtLogon' -Type DWord -Value 1
    }

    # Disable automatic maintenance
    if ($Script:WindowsBuildNumber -ge 7600) {
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\ScheduledDiagnostics' -Name 'EnabledExecution' -Type DWord -Value 0
    }

    # Disable Explorer SmartScreen
    if ($Script:WindowsBuildNumber -ge 9200 -and !$Script:WindowsServerCore) {
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name 'EnableSmartScreen' -Type DWord -Value 0
    }

    # Only send security telemetry
    if ($Script:WindowsBuildNumber -ge 10240) {
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Type DWord -Value 0
    }
}

Function Optimize-WindowsSettingsUser {
    [CmdletBinding()]
    Param()

    if ($Script:WindowsServerCore) {
        Write-Host -ForegroundColor Yellow '[Windows] Skipping user settings as not applicable to Windows Server Core.'
        return
    }

    Write-Host -ForegroundColor Green '[Windows] Applying user settings ...'

    # Remove Recycle Bin desktop icon
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Type DWord -Value 1
    if ($Script:WindowsBuildNumber -lt 7600) {
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Type DWord -Value 1
    }

    # Disable startup programs launch delay
    if ($Script:WindowsBuildNumber -ge 9200) {
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Type DWord -Value 0
    }

    # Remove volume control icon
    $AudioSrv = Get-Service -Name AudioSrv -ErrorAction SilentlyContinue
    if ($AudioSrv.StartType -eq 'Disabled') {
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCAVolume' -Type DWord -Value 1
    }
}

Function Optimize-WindowsUpdate {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows] Applying Windows Update settings ...'

    # Disable automatic updates
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Type DWord -Value 1

    # Enable recommended updates
    if ($Script:WindowsBuildNumber -lt 10240) {
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'IncludeRecommendedUpdates' -Type DWord -Value 1
    }

    # Disable MSRT updates
    Set-RegistryValue -Path 'HKCU:\Software\Policies\Microsoft\MRT' -Name 'DontOfferThroughWUAU' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows] Registering Microsoft Update ...'
    $ServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $ServiceRegistration = $ServiceManager.AddService2('7971f918-a847-4430-9279-4a52d1efe18d', 7, '')
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($ServiceRegistration)
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($ServiceManager)
}

#region Utilities

Function Get-WindowsInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWMICmdlet', '')]
    [CmdletBinding()]
    Param()

    if (Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue) {
        $Win32OpSys = Get-CimInstance -ClassName Win32_OperatingSystem -Verbose:$false
    } else {
        $Win32OpSys = Get-WmiObject -Class Win32_OperatingSystem -Verbose:$false
    }

    $Script:WindowsBuildNumber = [int]$Win32OpSys.BuildNumber
    $Script:WindowsProductType = $Win32OpSys.ProductType

    if (Test-Path -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion' -PathType Container) {
        $Script:Wow64Present = $true
    } else {
        $Script:Wow64Present = $false
    }

    $ExplorerPath = Join-Path -Path $env:windir -ChildPath 'explorer.exe'
    if (Test-Path -Path $ExplorerPath -PathType Leaf) {
        $Script:WindowsServerCore = $false
    } else {
        $Script:WindowsServerCore = $true
    }
}

Function Remove-DiskCleanupProfile {
    [CmdletBinding()]
    Param(
        [ValidateRange(0, 9999)]
        [int]$Number
    )

    $BasePath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $ValueName = 'StateFlags{0:D4}' -f $Number

    $Categories = Get-ChildItem -Path $BasePath -ErrorAction SilentlyContinue
    foreach ($Category in $Categories) {
        if ($Category.Property -contains $ValueName) {
            $RegPath = Join-Path -Path $BasePath -ChildPath $Category.PSChildName
            Remove-ItemProperty -Path $RegPath -Name $ValueName
        }
    }
}

Function Set-DiskCleanupProfile {
    <#
        Known categories
        - Active Setup Temp Folders
        - BranchCache
        - Content Indexer Cleaner
        - D3D Shader Cache
        - Delivery Optimization Files
        - Device Driver Packages
        - Diagnostic Data Viewer database files
        - Downloaded Program Files
        - DownloadsFolder
        - GameNewsFiles
        - GameStatisticsFiles
        - GameUpdateFiles
        - Internet Cache Files
        - Language Pack
        - Memory Dump Files
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
        - Windows Upgrade Log Files
    #>

    [CmdletBinding(DefaultParameterSetName = 'OptOut')]
    Param(
        [ValidateRange(0, 9999)]
        [int]$Number,

        [Parameter(ParameterSetName = 'OptOut')]
        [String[]]$ExcludeCategories,

        [Parameter(ParameterSetName = 'OptIn', Mandatory = $true)]
        [String[]]$IncludeCategories
    )

    $BasePath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $ValueName = 'StateFlags{0:D4}' -f $Number

    try {
        $BaseKey = Get-Item -Path $BasePath -ErrorAction Stop
        $ValidCategories = $BaseKey.GetSubKeyNames()
    } catch {
        throw 'Failed to enumerate categories for Disk Cleanup tool.'
    }

    if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
        $CategoriesParameter = $ExcludeCategories
    } else {
        $CategoriesParameter = $IncludeCategories
    }

    $UnknownCategories = [Collections.ArrayList]::new()
    foreach ($Category in $CategoriesParameter) {
        if ($ValidCategories -notcontains $Category) {
            $null = $UnknownCategories.Add($Category)
        }
    }

    $UnknownCategories.Sort()
    Write-Warning -Message ('Some Disk Cleanup categories will be ignored: {0}' -f [String]::Join(', ', $UnknownCategories))

    if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
        $Categories = $ValidCategories | Where-Object { $CategoriesParameter -notcontains $_ }
    } else {
        $Categories = $IncludeCategories
    }

    foreach ($Category in $ValidCategories) {
        $RegPath = Join-Path -Path $BasePath -ChildPath $Category
        $ValueData = 0

        if ($Categories -contains $Category) {
            $ValueData = 2
        }

        Set-RegistryValue -Path $RegPath -Name $ValueName -Type DWord -Value $ValueData
    }
}

Function Set-RegistryValue {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$Path,

        [Parameter(Mandatory = $true)]
        [String]$Name,

        [Parameter(Mandatory = $true)]
        [String]$Type,

        [Parameter(Mandatory = $true)]
        [String]$Value
    )

    try {
        if (!(Test-Path -Path $Path -PathType Container)) {
            $null = New-Item -Path $Path -Force -ErrorAction Stop
        }
    } catch {
        throw ('Failure creating registry key: {0}' -f $Path)
    }

    try {
        Set-ItemProperty @PSBoundParameters -ErrorAction Stop
    } catch {
        throw ('Failure creating registry value "{0}" ({1}) under key: {2}' -f $Name, $Type, $Path)
    }
}

Function Test-DotNetPresent {
    [CmdletBinding()]
    Param()

    $ClrVersions = '2.0', '4.0'
    foreach ($ClrVersion in $ClrVersions) {
        $VarName = 'DotNet{0}Present' -f $ClrVersion.Replace('.', $null)
        switch ($ClrVersion) {
            '2.0' { $RegPath = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v2.0.50727' }
            '4.0' { $RegPath = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full' }
        }

        $RegKey = Get-Item -Path $RegPath -ErrorAction SilentlyContinue
        if ($RegKey -and $RegKey.GetValue('Version')) {
            Set-Variable -Name $VarName -Scope Script -Value $true
        } else {
            Set-Variable -Name $VarName -Scope Script -Value $false
        }
    }
}

Function Test-IsAdministrator {
    [CmdletBinding()]
    Param()

    $User = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($User.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $true
    }
    return $false
}

#endregion

if (!(Test-IsAdministrator)) {
    throw 'You must have administrator privileges to run this script.'
}

Get-WindowsInfo

$Tasks = @(
    'WindowsUpdate',
    'WindowsDefender',
    'WindowsSecurity',
    'WindowsPower',
    'WindowsRestore',
    'WindowsSettingsComputer',
    'WindowsSettingsUser',
    'WindowsComponents',
    'DotNetFramework',
    'PowerShell',
    'Office365',
    'DiskCleanup'
)

foreach ($Task in $Tasks) {
    $Function = 'Optimize-{0}' -f $Task
    if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
        if ($ExcludeTasks -notcontains $Task) {
            & $Function
        }
    } else {
        if ($IncludeTasks -contains $Task) {
            & $Function
        }
    }
}
