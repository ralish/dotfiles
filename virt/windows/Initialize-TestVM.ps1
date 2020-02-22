#Requires -RunAsAdministrator

Function Optimize-WindowsComponents {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green 'Performing component store clean-up ...'
    & dism.exe /Online /Cleanup-Image /StartComponentCleanup
}

Function Optimize-WindowsFeatures {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$NetFx35SourcePath='D:\sources\sxs'
    )

    Write-Host -ForegroundColor Green 'Installing .NET Framework 3.5 ...'
    Install-WindowsFeature -Name NET-Framework-Core -Source $NetFx35SourcePath
}

Function Optimize-WindowsPowerShell {
    [CmdletBinding()]
    Param()

    if (!($PSVersionTable.PSVersion.Major -gt 5 -or ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -ge 1))) {
        Write-Warning 'Skipping PowerShell settings as version is not 5.1 or newer.'
        return
    }

    Write-Host -ForegroundColor Green 'Optimising Windows PowerShell ...'

    $null = Install-PackageProvider -Name NuGet -Force
    Install-Module -Name @('PSWindowsUpdate', 'PSWinGlue', 'PSWinVitals', 'SpeculationControl') -Scope AllUsers -Force
}

Function Optimize-WindowsSettings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green 'Optimising Windows settings ...'

    & .\LGPO.exe /q /s Security.inf
    & .\LGPO.exe /q /t Machine.txt
    & .\LGPO.exe /q /t User.txt

    # Remove the Recycle Bin icon from the desktop
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Value 1 -Type DWord
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Value 1 -Type DWord
}

Function Optimize-WindowsUpdate {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green 'Optimising Windows Update ...'

    # Enable recommended updates
    Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'IncludeRecommendedUpdates' -Value 1 -Type DWord

    # Opt-in to Microsoft Update
    $ServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $ServiceRegistration = ServiceManager.AddService2('7971f918-a847-4430-9279-4a52d1efe18d', 7, '')
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($ServiceRegistration)
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($ServiceManager)
}

Function Set-RegistryValue {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [String]$Value,

        [Parameter(Mandatory)]
        [String]$Type
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
        throw ('Failure creating registry value "{0}" under key: {1}' -f $Name, $Path)
    }
}

Optimize-WindowsSettings
Optimize-WindowsUpdate
Optimize-WindowsFeatures
Optimize-WindowsPowerShell
Optimize-WindowsComponents
