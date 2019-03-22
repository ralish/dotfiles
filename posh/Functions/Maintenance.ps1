# Update everything!
Function Update-AllTheThings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(DefaultParameterSetName='OptOut')]
    Param(
        [Parameter(ParameterSetName='OptOut')]
        [ValidateSet(
            'Windows',
            'Office',
            'VisualStudio',
            'PowerShell',
            'Scoop',
            'npm',
            'pip'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName='OptIn', Mandatory)]
        [ValidateSet(
            'Windows',
            'Office',
            'VisualStudio',
            'PowerShell',
            'Scoop',
            'npm',
            'pip'
        )]
        [String[]]$IncludeTasks
    )

    $Tasks = @{
        Windows = $null
        Office = $null
        VisualStudio = $null
        PowerShell = $null
        Scoop = $null
        npm = $null
        pip = $null
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
        Windows = $null
        Office = $null
        VisualStudio = $null
        PowerShell = $null
        Scoop = $null
        npm = $null
        pip = $null
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
        if (Get-Module -Name PowerShellGet -ListAvailable) {
            Write-Host -ForegroundColor Green -Object 'Updating PowerShell modules ...'
            Update-Module
        } else {
            Write-Warning -Message 'Unable to update PowerShell modules as PowerShellGet module not available.'
        }

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

    if ($Tasks['npm']) {
        if (Get-Command -Name npm) {
            Write-Host -ForegroundColor Green -Object 'Updating npm ...'
            & npm update -g npm

            Write-Host -ForegroundColor Green -Object 'Updating npm modules ...'
            & npm update -g

            $Results.npm = $true
        } else {
            Write-Warning -Message 'Unable to install npm updates as npm command not found.'
            $Results.npm = $false
        }
    }

    if ($Tasks['pip']) {
        if (Get-Command -Name pip) {
            Write-Host -ForegroundColor Green -Object 'Updating pip ...'
            & python -m pip install --upgrade pip

            Write-Host -ForegroundColor Green -Object 'Updating pip modules ...'
            $Regex = [Regex]::new('^\S+==')
            $PipArgs = @('install', '-U')
            & pip freeze | ForEach-Object { $PipArgs += $Regex.Match($_).Value.TrimEnd('=') }
            Start-Process -FilePath pip -ArgumentList $PipArgs -NoNewWindow -Wait

            $Results.pip = $true
        } else {
            Write-Warning -Message 'Unable to install pip updates as pip command not found.'
            $Results.pip = $false
        }
    }

    return $Results
}
