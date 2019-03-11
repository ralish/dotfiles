# Update assorted applications
Function Update-AllTheThings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(DefaultParameterSetName='OptOut')]
    Param(
        [Parameter(ParameterSetName='OptOut')]
        [ValidateSet(
            'Office',
            'PowerShell',
            'Scoop',
            'VisualStudio',
            'Windows'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName='OptIn', Mandatory)]
        [ValidateSet(
            'Office',
            'PowerShell',
            'Scoop',
            'VisualStudio',
            'Windows'
        )]
        [String[]]$IncludeTasks
    )

    $Tasks = @{
        Office = $null
        PowerShell = $null
        Scoop = $null
        VisualStudio = $null
        Windows = $null
    }

    foreach ($Task in @($Tasks.Keys)) {
        if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
            if ($ExcludeTasks -contains $Task) {
                $Tasks[$Task] = $false
            } else {
                $Tasks[$Task] = $true
            }
        } else {
            if ($IncludeTasks -contains $Task) {
                $Tasks[$Task] = $true
            } else {
                $Tasks[$Task] = $false
            }
        }
    }

    if ($Tasks['Windows'] -or $Tasks['Office'] -or $Tasks['VisualStudio']) {
        if (!(Test-IsAdministrator)) {
            throw 'You must have administrator privileges to perform Windows, Office, or Visual Studio updates.'
        }
    }

    $Results = [PSCustomObject]@{
        Office = $null
        PowerShell = $null
        Scoop = $null
        VisualStudio = $null
        Windows = $null
    }

    if ($Tasks['Windows']) {
        if (Get-Module -Name PSWindowsUpdate -ListAvailable) {
            Write-Host -ForegroundColor Green -Object 'Installing Windows updates ...'
            $Results.Windows = Install-WindowsUpdate -IgnoreReboot -NotTitle Silverlight
            if (!$Results.Windows) {
                $Results.Windows = $true
            }
        } else {
            Write-Warning -Message 'Unable to install Windows updates as PSWindowsUpdate module not available.'
            $Results.Windows = $false
        }
    }

    # The new Update Now feature for Office 2013 Click-to-Run for Office365 and its associated command-line and switches
    # https://blogs.technet.microsoft.com/odsupport/2014/03/03/the-new-update-now-feature-for-office-2013-click-to-run-for-office365-and-its-associated-command-line-and-switches/
    #
    # The update runs asynchronously as there's no parameter to request waiting
    # for update completion. This behaviour can be emulated by watching various
    # registry keys but it's grotesque. The Wait-ForOfficeCTRUpdate function in
    # the Update-Office365Anywhere.ps1 script would make a good starting point.
    if ($Tasks['Office']) {
        $OfficeC2RClient = Join-Path -Path $env:ProgramFiles -ChildPath 'Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe'
        if (Test-Path -Path $OfficeC2RClient -PathType Leaf) {
            Write-Host -ForegroundColor Green -Object 'Installing Office updates ...'
            Start-Process -FilePath $OfficeC2RClient -ArgumentList @('/update', 'user', 'updatepromptuser=True') -NoNewWindow -Wait
            $Results.Office = $true
        } else {
            Write-Warning -Message 'Unable to install Office updates as Click-to-Run client not found.'
            $Results.Office = $false
        }
    }

    # Use command-line parameters to install Visual Studio 2017
    # https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2017
    if ($Tasks['VisualStudio']) {
        $VsInstaller = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Visual Studio\Installer\vs_installer.exe'
        if (Test-Path -Path $VsInstaller -PathType Leaf) {
            Write-Host -ForegroundColor Green -Object 'Updating Visual Studio Installer ...'
            Start-Process -FilePath $VsInstaller -ArgumentList @('--update', '--passive', '--norestart', '--wait') -NoNewWindow -Wait

            Write-Host -ForegroundColor Green -Object 'Updating Visual Studio ...'
            Start-Process -FilePath $VsInstaller -ArgumentList @('update', '--passive', '--norestart', '--wait') -NoNewWindow -Wait

            $Results.VisualStudio = $true
        } else {
            Write-Warning -Message 'Unable to install Visual Studio updates as VS Installer not found.'
            $Results.VisualStudio = $false
        }
    }

    if ($Tasks['PowerShell']) {
        Write-Host -ForegroundColor Green -Object 'Updating PowerShell modules ...'
        Update-Module

        if (Get-Command -Name Uninstall-ObsoleteModule) {
            Write-Host -ForegroundColor Green -Object 'Uninstalling obsolete PowerShell modules ...'
            Uninstall-ObsoleteModule
        } else {
            Write-Warning -Message 'Unable to uninstall obsolete PowerShell modules as Uninstall-ObsoleteModule command not available.'
        }

        Write-Host -ForegroundColor Green -Object 'Updating PowerShell help ...'
        Update-Help -Force

        $Results.PowerShell = $true
    }

    if ($Tasks['Scoop']) {
        if (Get-Command -Name scoop) {
            Write-Host -ForegroundColor Green -Object 'Updating Scoop ...'
            & scoop update --quiet

            Write-Host -ForegroundColor Green -Object 'Updating Scoop apps ...'
            & scoop update * --quiet

            $Results.Scoop = $true
        } else {
            Write-Warning -Message 'Unable to install Scoop updates as scoop command not found.'
            $Results.Scoop = $false
        }
    }

    return $Results
}
