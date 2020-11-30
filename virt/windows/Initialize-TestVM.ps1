[CmdletBinding(DefaultParameterSetName = 'OptOut')]
Param(
    [Parameter(ParameterSetName = 'OptOut')]
    [ValidateSet(
        'DotNet',
        'Office365',
        'PowerShell',
        'WindowsComponents',
        'WindowsDefender',
        'WindowsFeatures',
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
        'DotNet',
        'Office365',
        'PowerShell',
        'WindowsComponents',
        'WindowsDefender',
        'WindowsFeatures',
        'WindowsPower',
        'WindowsRestore',
        'WindowsSecurity',
        'WindowsSettingsComputer',
        'WindowsSettingsUser',
        'WindowsUpdate'
    )]
    [String[]]$IncludeTasks
)

Function Optimize-DotNet {
    [CmdletBinding()]
    Param()

    Test-DotNetPresent

    if ($script:DotNet20Present) {
        Write-Host -ForegroundColor Green '[DotNet] Applying .NET Framework 2.x/3.x settings ...'

        # Enable strong cryptography
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        if ($script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        }

        # Let OS choose protocols
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        if ($script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        }
    } else {
        Write-Warning -Message 'Skipping .NET Framework 2.x/3.x settings as not installed.'
    }

    if ($script:DotNet40Present) {
        Write-Host -ForegroundColor Green '[DotNet] Applying .NET Framework 4.x settings ...'

        # Enable strong cryptography
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        if ($script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        }

        # Let OS choose protocols
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        if ($script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        }
    } else {
        Write-Warning -Message 'Skipping .NET Framework 4.x settings as not installed.'
    }
}

Function Optimize-Office365 {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Office 365] Disabling automatic updates ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Office\16.0\Common\OfficeUpdate' -Name 'EnableAutomaticUpdates' -Type DWord -Value 0
}

Function Optimize-PowerShell {
    [CmdletBinding()]
    Param()

    if (!($PSVersionTable.PSVersion.Major -ge 5)) {
        Write-Warning 'Skipping PowerShell settings as version is not 5.0 or newer.'
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
            # way to invalidate it other than restarting the session.
            if (Get-Module -Name PowerShellGet) {
                Write-Host -ForegroundColor Cyan '[PowerShell] You must restart PowerShell to complete NuGet package provider installation.'
                Write-Host -ForegroundColor Cyan '             Re-run this script afterwards to continue initial PowerShell configuration.'
                return
            }
        }
    }

    Write-Host -ForegroundColor Green '[PowerShell] Setting PSGallery repository to trusted ...'
    $null = Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    Write-Host -ForegroundColor Green '[PowerShell] Installing PowerShellGet module ...'
    $PSGetLoaded = Get-Module -Name PowerShellGet | Sort-Object -Property Version -Descending | Select-Object -First 1
    Install-Module -Name PowerShellGet -Force
    Import-Module -Name PowerShellGet -Force
    $PSGetInstalled = Get-Module -Name PowerShellGet | Sort-Object -Property Version -Descending | Select-Object -First 1

    # PowerShellGet loads various .NET types, and types can't be unloaded (at
    # least not easily). That can be problematic as when loading a new version
    # of PowerShellGet into a session with an earlier version already loaded,
    # some types may have been updated but cannot be loaded to replace earlier
    # loaded types. The simple solution is to restart PowerShell so we have a
    # new session which isn't "polluted" by earlier module imports.
    if ($PSGetLoaded.Version -ne $PSGetInstalled.Version) {
        Write-Host -ForegroundColor Cyan '[PowerShell] You must restart PowerShell to complete PowerShellGet module installation.'
        Write-Host -ForegroundColor Cyan '             Re-run this script afterwards to continue initial PowerShell configuration.'
        return
    }

    Write-Host -ForegroundColor Green '[PowerShell] Determining modules to install ...'
    $Modules = @('SpeculationControl', 'PSWindowsUpdate', 'PSWinGlue', 'PSWinVitals')
    if (!(Get-Module -Name PSReadLine)) {
        $Modules += 'PSReadLine'
    }

    Write-Host -ForegroundColor Green '[PowerShell] Installing modules ...'
    foreach ($Module in $Modules) {
        Write-Host -ForegroundColor Gray ('[PowerShell] - {0}' -f $Module)
        $null = Install-Module -Name $Module -Force
    }

    if ($Modules -notcontains 'PSReadLine') {
        Write-Host -ForegroundColor Cyan '[PowerShell] To update PSReadLine run the following from an elevated Command Prompt:'
        Write-Host -ForegroundColor Cyan '             powershell -NoProfile -NonInteractive -Command "Install-Module -Name PSReadLine -AllowPrerelease -Force"'
    }
}

Function Optimize-WindowsComponents {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green -NoNewline '[Windows] Performing component store clean-up ...'
    & dism.exe /Online /Cleanup-Image /StartComponentCleanup
    Write-Host
}

Function Optimize-WindowsDefender {
    [CmdletBinding()]
    Param()

    $MpCmdRun = Join-Path -Path $env:ProgramFiles -ChildPath 'Windows Defender\MpCmdRun.exe'
    if (!(Test-Path -Path $MpCmdRun -PathType Leaf)) {
        Write-Warning -Message 'Skipping Windows Defender settings as unable to find MpCmdRun.exe.'
        return
    }

    try {
        Get-MpComputerStatus -ErrorAction Stop
        if ($MpStatus.IsTamperProtected) {
            Write-Warning -Message 'Skipping Windows Defender settings as tamper protection is enabled.'
            return
        }
    } catch [System.Management.Automation.CommandNotFoundException] {
        Write-Warning -Message 'Unable to query Windows Defender status as Get-MpComputerStatus command not available.'
    } catch [Microsoft.Management.Infrastructure.CimException] {
        # The extrinsic Method could not be executed
        if ($_.FullyQualifiedErrorId -match '^MI RESULT 16,') {
            Write-Warning -Message 'Unable to query Windows Defender status as Get-MpComputerStatus returned: MI_RESULT_METHOD_NOT_AVAILABLE'
        } else {
            Write-Error -Message $_
            return
        }
    }

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling behaviour monitoring ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableBehaviorMonitoring' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling downloaded files and attachments scanning ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableIOAVProtection' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling file and program activity monitoring ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableOnAccessProtection' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling real-time protection ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name 'DisableRealtimeMonitoring' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling scheduled remediation scans ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Remediation' -Name 'Scan_ScheduleDay' -Type DWord -Value 8

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling signature update before scheduled scan ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Scan' -Name 'CheckForSignaturesBeforeRunningScan' -Type DWord -Value 0

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling scheduled scans ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Scan' -Name 'ScheduleDay' -Type DWord -Value 8

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling scan on signature update ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'DisableScanOnUpdate' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling startup update on absent malware engine ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'DisableUpdateOnStartupWithoutEngine' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling scheduled signature updates ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'ScheduleDay' -Type DWord -Value 8

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling signature update on startup ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'UpdateOnStartUp' -Type DWord -Value 0

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling Microsoft Active Protection Service ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Spynet' -Name 'SpynetReporting' -Type DWord -Value 0

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling submission of file samples ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender\Spynet' -Name 'SubmitSamplesConsent' -Type DWord -Value 2

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling recent activity and scan results notifications ...'
    Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows Defender Security Center\Virus and threat protection' -Name 'SummaryNotificationDisabled' -Type DWord -Value 1

    if ($script:WindowsBuildNumber -le '17763') {
        Write-Host -ForegroundColor Green '[Windows Defender] Disabling service ...'
        Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender' -Name 'DisableAntiSpyware' -Type DWord -Value 1
    }

    Write-Host -ForegroundColor Green -NoNewline '[Windows Defender] Removing definitions ...'
    & $MpCmdRun -RemoveDefinitions -All
    Write-Host
}

Function Optimize-WindowsFeatures {
    [CmdletBinding()]
    Param()

    $DismParams = [Collections.ArrayList]@(
        '/Online',
        '/Enable-Feature',
        '/FeatureName:NetFx3'
    )

    # The /All parameter is only available since Windows 8 and Server 2012
    if ($script:WindowsBuildNumber -ge '9200') {
        $null = $DismParams.Add('/All')
    }

    # Windows Server 2019 requires access to the installation media as it seems
    # the relevant files can't be automatically retrieved from Windows Update.
    if ($script:WindowsBuildNumber -eq '17763' -and $script:WindowsProductType -ne 1) {
        $SxsPath = 'D:\sources\sxs'
        if (!(Test-Path -Path $SxsPath -PathType Container)) {
            Write-Warning -Message ('Skipping .NET Framework 3.5 installation as sources path not present: {0}' -f $SxsPath)
            return
        }

        $null = $DismParams.Add(('/Source:{0}' -f $SxsPath))
    }

    Write-Host -ForegroundColor Green -NoNewline '[Windows] Installing .NET Framework 3.5 ...'
    Start-Process -FilePath 'dism.exe' -ArgumentList $DismParams -NoNewWindow -Wait
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

    if ($script:WindowsProductType -ne 1) {
        Write-Warning -Message 'Skipping disabling System Restore as unsupported on server SKUs.'
        return
    }

    Write-Host -ForegroundColor Green '[Windows] Disabling System Restore ...'
    Disable-ComputerRestore -Drive $env:SystemDrive
}

Function Optimize-WindowsSecurity {
    [CmdletBinding()]
    Param()

    Test-Wow64Present

    Write-Host -ForegroundColor Green '[Windows] Applying security policy ...'
    $SecEditDb = Join-Path $env:windir 'Security\Local.sdb'
    $SecEditCfg = Join-Path $env:windir 'Temp\SecPol.cfg'

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
    if ($script:Wow64Present) {
        Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Type DWord -Value 2688
    }
}

Function Optimize-WindowsSettingsComputer {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows] Applying computer settings ...'

    # Disable automatic maintenance
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\ScheduledDiagnostics' -Name 'EnabledExecution' -Type DWord -Value 0

    # Do not display Server Manager automatically at logon
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Server\ServerManager' -Name 'DoNotOpenAtLogon' -Type DWord -Value 1

    # Disable Explorer SmartScreen
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name 'EnableSmartScreen' -Type DWord -Value 0

    # Disable Shutdown Event Tracker
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Reliability' -Name 'ShutdownReasonOn' -Type DWord -Value 0
}

Function Optimize-WindowsSettingsUser {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows] Applying user settings ...'

    # Remove volume control icon
    $AudioSrv = Get-Service -Name AudioSrv -ErrorAction SilentlyContinue
    if ($AudioSrv.StartType -eq 'Disabled') {
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCAVolume' -Type DWord -Value 1
    }

    # Remove Recycle Bin desktop icon
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Type DWord -Value 1
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Type DWord -Value 1

    # Disable startup programs launch delay
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Type DWord -Value 0
}

Function Optimize-WindowsUpdate {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows Update] Disabling automatic updates ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Update] Enabling recommended updates ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'IncludeRecommendedUpdates' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Update] Registering Microsoft Update ...'
    $ServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $ServiceRegistration = $ServiceManager.AddService2('7971f918-a847-4430-9279-4a52d1efe18d', 7, '')
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($ServiceRegistration)
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($ServiceManager)

    Write-Host -ForegroundColor Green '[Windows Update] Suppressing MSRT updates ...'
    Set-RegistryValue -Path 'HKCU:\Software\Policies\Microsoft\MRT' -Name 'DontOfferThroughWUAU' -Type DWord -Value 1
}

#region Utilities

Function Get-WindowsInfo {
    [CmdletBinding()]
    Param()

    if (Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue) {
        $Win32OpSys = Get-CimInstance -ClassName Win32_OperatingSystem -Verbose:$false
    } else {
        $Win32OpSys = Get-WmiObject -Class Win32_OperatingSystem -Verbose:$false
    }

    $script:WindowsBuildNumber = [int]$Win32OpSys.BuildNumber
    $script:WindowsProductType = $Win32OpSys.ProductType
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
        $VarName = 'DotNet{0}Present' -f $ClrVersion.Replace('.', '')
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

Function Test-Wow64Present {
    [CmdletBinding()]
    Param()

    if (Test-Path -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion' -PathType Container) {
        $script:Wow64Present = $true
    } else {
        $script:Wow64Present = $false
    }
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
    'WindowsFeatures',
    'WindowsComponents',
    'DotNet',
    'PowerShell',
    'Office365'
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
