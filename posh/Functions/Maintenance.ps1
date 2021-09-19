if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing maintenance functions ...')

# Update everything!
Function Update-AllTheThings {
    [CmdletBinding(DefaultParameterSetName = 'OptOut')]
    Param(
        [Parameter(ParameterSetName = 'OptOut')]
        [ValidateSet(
            'Windows',
            'Office',
            'VisualStudio',
            'PowerShell',
            'ModernApps',
            'Scoop',
            'DotNetTools',
            'NodejsPackages',
            'PythonPackages',
            'RubyGems'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName = 'OptIn', Mandatory)]
        [ValidateSet(
            'Windows',
            'Office',
            'VisualStudio',
            'PowerShell',
            'ModernApps',
            'Scoop',
            'DotNetTools',
            'NodejsPackages',
            'PythonPackages',
            'RubyGems'
        )]
        [String[]]$IncludeTasks
    )

    $Tasks = @{
        Windows        = $null
        Office         = $null
        VisualStudio   = $null
        PowerShell     = $null
        ModernApps     = $null
        Scoop          = $null
        DotNetTools    = $null
        NodejsPackages = $null
        PythonPackages = $null
        RubyGems       = $null
    }

    $TasksDone = 0
    $TasksTotal = 0

    foreach ($Task in @($Tasks.Keys)) {
        if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
            if ($ExcludeTasks -contains $Task) {
                $Tasks[$Task] = $false
            } else {
                $Tasks[$Task] = $true
                $TasksTotal++
            }
        } else {
            if ($IncludeTasks -contains $Task) {
                $Tasks[$Task] = $true
                $TasksTotal++
            } else {
                $Tasks[$Task] = $false
            }
        }
    }

    if ($Tasks['Windows'] -or $Tasks['Office'] -or $Tasks['VisualStudio'] -or $Tasks['ModernApps']) {
        if (!(Test-IsAdministrator)) {
            throw 'You must have administrator privileges to perform Windows, Office, Visual Studio, or Modern Apps updates.'
        }
    }

    $Results = [PSCustomObject]@{
        Windows        = $null
        Office         = $null
        VisualStudio   = $null
        PowerShell     = $null
        ModernApps     = $null
        Scoop          = $null
        DotNetTools    = $null
        NodejsPackages = $null
        PythonPackages = $null
        RubyGems       = $null
    }

    $WriteProgressParams = @{
        Id       = 0
        Activity = 'Updating all the things'
    }

    if ($Tasks['Windows']) {
        Write-Progress @WriteProgressParams -Status 'Updating Windows' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.Windows = Update-Windows -PassThru
        $TasksDone++
    }

    if ($Tasks['Office']) {
        Write-Progress @WriteProgressParams -Status 'Updating Office' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.Office = Update-Office -PassThru -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['VisualStudio']) {
        Write-Progress @WriteProgressParams -Status 'Updating Visual Studio' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.VisualStudio = Update-VisualStudio -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['PowerShell']) {
        Write-Progress @WriteProgressParams -Status 'Updating PowerShell' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.PowerShell = Update-PowerShell -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['ModernApps']) {
        Write-Progress @WriteProgressParams -Status 'Updating Microsoft Store apps' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.ModernApps = Update-ModernApps
        $TasksDone++
    }

    if ($Tasks['Scoop']) {
        Write-Progress @WriteProgressParams -Status 'Updating Scoop apps' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.Scoop = Update-Scoop -CaptureOutput -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['DotNetTools']) {
        Write-Progress @WriteProgressParams -Status 'Updating .NET tools' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.DotNetTools = Update-DotNetTools -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['NodejsPackages']) {
        Write-Progress @WriteProgressParams -Status 'Updating Node.js packages' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.NodejsPackages = Update-NodejsPackages
        $TasksDone++
    }

    if ($Tasks['PythonPackages']) {
        Write-Progress @WriteProgressParams -Status 'Updating Python packages' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.PythonPackages = Update-PythonPackages
        $TasksDone++
    }

    if ($Tasks['RubyGems']) {
        Write-Progress @WriteProgressParams -Status 'Updating Ruby gems' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.RubyGems = Update-RubyGems
        $TasksDone++
    }

    Write-Progress @WriteProgressParams -Completed

    return $Results
}

# Update Modern Apps (Microsoft Store)
Function Update-ModernApps {
    [CmdletBinding()]
    Param()

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Modern Apps updates.'
    }

    $Namespace = 'root\CIMv2\mdm\dmmap'
    $Class = 'MDM_EnterpriseModernAppManagement_AppManagement01'
    $Method = 'UpdateScanMethod'

    $Session = New-CimSession
    $Instance = Get-CimInstance -Namespace $Namespace -ClassName $Class
    $Result = $Session.InvokeMethod($Namespace, $Instance, $Method, $null)

    return $Result
}

# Update Microsoft Office (Click-to-Run only)
Function Update-Office {
    [CmdletBinding()]
    Param(
        [Switch]$PassThru,

        [ValidateRange('NonNegative')]
        [Int]$ProgressParentId
    )

    # The new Update Now feature for Office 2013 Click-to-Run for Office365 and its associated command-line and switches
    # https://blogs.technet.microsoft.com/odsupport/2014/03/03/the-new-update-now-feature-for-office-2013-click-to-run-for-office365-and-its-associated-command-line-and-switches/

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Office updates.'
    }

    $OfficeC2RClient = Join-Path -Path $env:ProgramFiles -ChildPath 'Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe'
    if (!(Test-Path -LiteralPath $OfficeC2RClient -PathType Leaf)) {
        Write-Error -Message 'Unable to install Office updates as Click-to-Run client not found.'
        return
    }

    $WriteProgressParams = @{
        Activity = 'Updating Office 365'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    Write-Progress @WriteProgressParams
    & $OfficeC2RClient /update user updatepromptuser=True
    Start-Sleep -Seconds 3

    do {
        $OfficeRegPath = 'HKLM:\Software\Microsoft\Office\ClickToRun'
        $OfficeRegKey = Get-Item -LiteralPath $OfficeRegPath

        $ExecutingScenario = $OfficeRegKey.GetValue('ExecutingScenario')
        if ($ExecutingScenario) {
            Write-Progress @WriteProgressParams -Status ('Executing scenario: {0}' -f $ExecutingScenario)
        } else {
            $LastScenario = $OfficeRegKey.GetValue('LastScenario')
            $LastScenarioResult = $OfficeRegKey.GetValue('LastScenarioResult')
            break
        }

        $TasksRegPath = Join-Path -Path $OfficeRegPath -ChildPath ('Scenario\{0}\TasksState' -f $ExecutingScenario)
        $TasksRegKey = Get-Item -LiteralPath $TasksRegPath

        foreach ($Task in $TasksRegKey.GetValueNames()) {
            $TaskName = $Task.Split(':')[0]
            $TaskStatus = $TasksRegKey.GetValue($Task)

            if ($TaskStatus -eq 'TASKSTATE_FAILED') {
                Write-Warning -Message ('Office update task failed in {0} scenario: {1}' -f $ExecutingScenario, $TaskName)
            }

            if ($TaskStatus -eq 'TASKSTATE_CANCELLED') {
                Write-Warning -Message ('Office update task cancelled in {0} scenario: {1}' -f $ExecutingScenario, $TaskName)
            }
        }

        Start-Sleep -Seconds 5
    } while ($true)

    Write-Verbose -Message ('Office update finished {0} scenario with result: {1}' -f $LastScenario, $LastScenarioResult)
    Write-Progress @WriteProgressParams -Completed

    if (!$PassThru) {
        return
    }

    if ($LastScenarioResult -ne 'Success') {
        return $false
    }

    return $true
}

# Update PowerShell modules & built-in help
Function Update-PowerShell {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Switch]$IncludeDscModules,
        [Switch]$Force,

        [ValidateRange('NonNegative')]
        [Int]$ProgressParentId
    )

    if (Get-Module -Name PowerShellGet -ListAvailable) {
        $WriteProgressParams = @{
            Activity = 'Updating PowerShell modules'
        }

        if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
            $WriteProgressParams['ParentId'] = $ProgressParentId
            $WriteProgressParams['Id'] = $ProgressParentId + 1
        }

        Write-Progress @WriteProgressParams -Status 'Enumerating installed modules' -PercentComplete 0
        $InstalledModules = Get-InstalledModule

        # Percentage of the total progress for Update-Module
        $ProgressPercentUpdatesBase = 10
        if ($InstalledModules -contains 'AWS.Tools.Installer') {
            $ProgressPercentUpdatesSection = 80
        } else {
            $ProgressPercentUpdatesSection = 90
        }

        if (!$IncludeDscModules) {
            Write-Progress @WriteProgressParams -Status 'Enumerating DSC modules for exclusion' -PercentComplete 5

            # Get-DscResource likes to output multiple progress bars but doesn't have the manners to
            # clean them up. The result is a total visual mess when we've got our own progress bars.
            $OriginalProgressPreference = $ProgressPreference
            Set-Variable -Name 'ProgressPreference' -Scope Global -Value 'Ignore'

            try {
                # Get-DscResource may output various errors, most often due to duplicate resources.
                # That's frequently the case with, for example, the PackageManagement module being
                # available in multiple locations accessible from the PSModulePath.
                $DscModules = @(Get-DscResource -Module * -ErrorAction Ignore | Select-Object -ExpandProperty ModuleName -Unique)
            } finally {
                Set-Variable -Name 'ProgressPreference' -Scope Global -Value $OriginalProgressPreference
            }
        }

        if (Test-IsWindows) {
            $ScopePathCurrentUser = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
            $ScopePathAllUsers = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
        } else {
            $ScopePathCurrentUser = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
            $ScopePathAllUsers = '/usr/local/share'
        }

        # Update all modules compatible with Update-Module
        for ($ModuleIdx = 0; $ModuleIdx -lt $InstalledModules.Count; $ModuleIdx++) {
            $Module = $InstalledModules[$ModuleIdx]

            if (!$IncludeDscModules -and $Module.Name -in $DscModules) {
                Write-Verbose -Message ('Skipping DSC module: {0}' -f $Module.Name)
                continue
            }

            if ($Module.Name -match '^AWS\.Tools\.' -and $Module.Repository -notmatch 'PSGallery') {
                continue
            }

            $UpdateModuleParams = @{
                Name          = $Module.Name
                AcceptLicense = $true
            }

            if ($Module.InstalledLocation.StartsWith($ScopePathCurrentUser)) {
                $UpdateModuleParams['Scope'] = 'CurrentUser'
            } elseif ($Module.InstalledLocation.StartsWith($ScopePathAllUsers)) {
                $UpdateModuleParams['Scope'] = 'AllUsers'
            } else {
                Write-Warning -Message ('Unable to determine install scope for module: {0}' -f $Module)
                continue
            }

            if ($PSCmdlet.ShouldProcess($Module.Name, 'Update')) {
                $PercentComplete = ($ModuleIdx + 1) / $InstalledModules.Count * $ProgressPercentUpdatesSection + $ProgressPercentUpdatesBase
                Write-Progress @WriteProgressParams -Status ('Updating {0}' -f $Module.Name) -PercentComplete $PercentComplete
                Update-Module @UpdateModuleParams
            }
        }

        # The modular AWS Tools for PowerShell has its own mechanism
        if ($InstalledModules -contains 'AWS.Tools.Installer') {
            if ($PSCmdlet.ShouldProcess('AWS.Tools', 'Update')) {
                $PercentComplete = $ProgressPercentUpdatesBase + $ProgressPercentUpdatesSection
                Write-Progress @WriteProgressParams -Status 'Updating AWS modules' -PercentComplete $PercentComplete
                Update-AWSToolsModule -CleanUp
            }
        }

        Write-Progress @WriteProgressParams -Completed
    } else {
        Write-Warning -Message 'Unable to update PowerShell modules as PowerShellGet module not available.'
    }

    if ($PSCmdlet.ShouldProcess('Obsolete modules', 'Uninstall')) {
        if (Get-Command -Name Uninstall-ObsoleteModule -ErrorAction Ignore) {
            if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
                Uninstall-ObsoleteModule -ProgressParentId $ProgressParentId
            } else {
                Uninstall-ObsoleteModule
            }
        } else {
            Write-Warning -Message 'Unable to uninstall obsolete PowerShell modules as Uninstall-ObsoleteModule command not available.'
        }
    }

    if ($PSCmdlet.ShouldProcess('PowerShell help', 'Update')) {
        try {
            Update-Help -Force:$Force -ErrorAction Stop
        } catch {
            Write-Warning -Message 'Some errors were reported while updating PowerShell module help.'
        }
    }

    return $true
}

# Update Scoop & installed apps
Function Update-Scoop {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
    [CmdletBinding()]
    Param(
        [Switch]$CaptureOutput,

        [ValidateRange('NonNegative')]
        [Int]$ProgressParentId
    )

    if (!(Get-Command -Name scoop -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Scoop apps as scoop command not found.'
        return
    }

    $WriteProgressParams = @{
        Activity = 'Updating Scoop'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    Write-Progress @WriteProgressParams -Status 'Updating module & repository' -PercentComplete 0
    Write-Verbose -Message 'Updating Scoop: scoop update --quiet'
    if ($CaptureOutput) {
        $ScoopOutput = & scoop update --quiet 6>&1
    } else {
        & scoop update --quiet
        Write-Host
    }

    Write-Progress @WriteProgressParams -Status 'Updating apps' -PercentComplete 20
    Write-Verbose -Message 'Updating Scoop apps: scoop update * --quiet'
    if ($CaptureOutput) {
        $ScoopOutput += & scoop update * --quiet 6>&1
    } else {
        & scoop update * --quiet
        Write-Host
    }

    Write-Progress @WriteProgressParams -Status 'Uninstalling obsolete apps' -PercentComplete 80
    Write-Verbose -Message 'Uninstalling obsolete Scoop apps: scoop cleanup *'
    if ($CaptureOutput) {
        $ScoopOutput += & scoop cleanup * 6>&1
    } else {
        & scoop cleanup *
        Write-Host
    }

    Write-Progress @WriteProgressParams -Completed

    if ($CaptureOutput) {
        return $ScoopOutput
    }
}

# Update Microsoft Visual Studio
Function Update-VisualStudio {
    [CmdletBinding()]
    Param(
        [ValidateRange('NonNegative')]
        [Int]$ProgressParentId
    )

    # Use command-line parameters to install Visual Studio
    # https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Visual Studio updates.'
    }

    $VsInstallerExe = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Visual Studio\Installer\vs_installer.exe'
    if (!(Test-Path -LiteralPath $VsInstallerExe -PathType Leaf)) {
        Write-Error -Message 'Unable to update Visual Studio as VSInstaller not found.'
        return
    }

    if (!(Get-Module -Name VSSetup -ListAvailable)) {
        Write-Error -Message 'Unable to update Visual Studio as VSSetup module not available.'
        return
    }

    $Instances = @(Get-VSSetupInstance)
    if ($Instances.Count -ne 1) {
        if ($Instances.Count -eq 0) {
            Write-Error -Message 'Get-VSSetupInstance returned no instances.'
        } else {
            Write-Error -Message 'Get-VSSetupInstance returned multiple instances.'
        }
        return $false
    }

    $WriteProgressParams = @{
        Activity = 'Updating Visual Studio'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $VsInstallerArgs = @(
        'update'
        '--installPath'
        ('"{0}"' -f $Instances.InstallationPath)
        '--passive'
        '--norestart'
    )

    # Waiting on the Visual Studio Installer to complete is far more difficult
    # than at all reasonable. Providing the above parameters and waiting on the
    # process to exit is sufficient *if* the installer itself does not need to
    # be updated. In the latter case however, the original setup process will
    # exit while the update continues in the newly launched updated installer.
    #
    # Contrary to what the official documentation states the "--wait" parameter
    # does not work; in fact, it doesn't appear to even be a valid option. The
    # best approach I've found is to try to acquire the named mutex used by the
    # installer: DevdivInstallerUI. This is obviously undocumented and a hack,
    # but all of the other approaches I've found have more serious downsides.
    Write-Progress @WriteProgressParams -Status 'Running Visual Studio Installer'
    $VsInstaller = Start-Process -FilePath $VsInstallerExe -ArgumentList $VsInstallerArgs -PassThru -Wait

    # Wait a few seconds in case the original installer process has exited but
    # the updated installer process has not yet started. I'm not sure if this
    # is actually a possible scenario, but am just being cautious. Obviously a
    # not particularly durable hack, but more durable approaches are a pain.
    Start-Sleep -Seconds 3

    # Try to acquire the Visual Studio Installer mutex. If the named mutex is
    # created by us, then an updated installer is not running. If it already
    # exists, wait on it until we acquire it. The distinction is important as
    # if an updated Visual Studio Installer is running, the exit code we have
    # from the original instance is not meaningful for the update operation.
    $VsInstallerMutexCreated = $false
    $VsInstallerMutex = [Threading.Mutex]::new($false, 'DevdivInstallerUI', [ref]$VsInstallerMutexCreated)
    if (!$VsInstallerMutexCreated) {
        Write-Progress @WriteProgressParams -Status 'Waiting for updated installer to exit'
        $null = $VsInstallerMutex.WaitOne()
        $VsInstallerMutex.ReleaseMutex()
    }
    $VsInstallerMutex.Close()

    Write-Progress @WriteProgressParams -Completed
    if ($VsInstallerMutexCreated) {
        switch ($VsInstaller.ExitCode) {
            3010 { Write-Warning -Message 'Visual Studio successfully updated but requires a reboot.' }
            0 { }
            Default {
                Write-Error -Message ('Visual Studio Installer returned exit code: {0}' -f $VsInstaller.ExitCode)
                return $false
            }
        }
    } else {
        Write-Warning -Message 'Visual Studio Installer exit code is unknown as the update occurred in a different process.'
    }

    return $true
}

# Update Microsoft Windows
Function Update-Windows {
    [CmdletBinding()]
    Param(
        [Switch]$PassThru
    )

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Windows updates.'
    }

    if (!(Get-Module -Name PSWindowsUpdate -ListAvailable)) {
        Write-Error -Message 'Unable to install Windows updates as PSWindowsUpdate module not available.'
        return
    }

    $Results = Get-WindowsUpdate -IgnoreReboot -NotTitle Silverlight
    if ($Results) {
        return $Results
    }

    if ($PassThru) {
        return $true
    }
}
