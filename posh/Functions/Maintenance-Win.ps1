$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Maintenance (Windows)'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
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
    $UpdateScan = $Session.InvokeMethod($Namespace, $Instance, $Method, $null)

    $Result = $true
    if ($UpdateScan.ReturnValue.Value -ne 0) {
        Write-Error -Message ('Update of Modern Apps returned: {0}' -f $UpdateScan.ReturnValue.Value)
        $Result = $false
    }

    return $Result
}

# Update Microsoft Office (Click-to-Run only)
Function Update-Office {
    [CmdletBinding()]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

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

    return $LastScenarioResult
}

# Update Scoop & installed apps
Function Update-Scoop {
    [CmdletBinding()]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
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

    $Result = [PSCustomObject]@{
        UpdateScoop = $null
        UpdateApps  = $null
        CleanupApps = $null
    }

    [String[]]$UpdateScoopArgs = 'update', '--quiet'
    [String[]]$UpdateAppsArgs = 'update', '*', '--quiet'
    [String[]]$CleanupAppsArgs = 'cleanup', '-k', '*'

    Write-Progress @WriteProgressParams -Status 'Updating module & repository' -PercentComplete 1
    Write-Verbose -Message ('Updating Scoop: scoop {0}' -f ($UpdateScoopArgs -join ' '))
    $Result.UpdateScoop = & scoop @UpdateScoopArgs 6>&1

    Write-Progress @WriteProgressParams -Status 'Updating apps' -PercentComplete 20
    Write-Verbose -Message ('Updating Scoop apps: scoop {0}' -f ($UpdateAppsArgs -join ' '))
    $Result.UpdateApps = & scoop @UpdateAppsArgs 6>&1

    Write-Progress @WriteProgressParams -Status 'Uninstalling obsolete apps' -PercentComplete 80
    Write-Verbose -Message ('Uninstalling obsolete Scoop apps: scoop {0}' -f ($CleanupAppsArgs -join ' '))
    $Result.CleanupApps = & scoop @CleanupAppsArgs 6>&1

    Write-Progress @WriteProgressParams -Completed

    return $Result
}

# Update Microsoft Visual Studio
#
# Use command-line parameters to install, update, and manage Visual Studio
# https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio
Function Update-VisualStudio {
    [CmdletBinding()]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Visual Studio updates.'
    }

    $VsInstallerExe = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Visual Studio\Installer\vs_installer.exe'
    if (!(Test-Path -LiteralPath $VsInstallerExe -PathType Leaf)) {
        Write-Error -Message 'Unable to update Visual Studio as VSInstaller not found.'
        return $false
    }

    Test-ModuleAvailable -Name VSSetup

    $VsSetupInstances = @(Get-VSSetupInstance | Sort-Object -Property InstallationVersion)
    if ($VsSetupInstances.Count -eq 0) {
        Write-Error -Message 'Get-VSSetupInstance returned no instances.'
        return $false
    }

    $WriteProgressParams = @{
        Activity = 'Updating Visual Studio'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    # Set to false if an unexpected exit code is returned for any update
    $VsInstallerStatus = $true

    for ($Idx = 0; $Idx -lt $VsSetupInstances.Count; $Idx++) {
        $VsSetupInstance = $VsSetupInstances[$Idx]
        $VsDisplayName = $VsSetupInstance.DisplayName

        # Waiting on the Visual Studio Installer to complete is more difficult
        # than at all reasonable. Providing the below parameters and waiting on
        # the process to exit is sufficient *if* the installer itself does not
        # need to be updated. In the latter case, the original setup process
        # will exit while the update continues using the updated installer.
        #
        # Contrary to the official documentation the "--wait" parameter doesn't
        # work, and in fact, doesn't appear to even be a valid option. The best
        # approach I've found is to try to acquire the named mutex used by the
        # installer: DevdivInstallerUI. While undocumented and a hack, all of
        # the other approaches I've found have more serious downsides. We use
        # this approach later after the original setup process has exited.
        #
        # In addition, when launched via a console application the installer
        # will spam the terminal with various debug output, even if running in
        # quiet mode. I can't find any command-line parameter to suppress it,
        # and redirecting the output streams doesn't work either. I'm guessing
        # it's doing something nefarious if it detects it was launched from a
        # console environment. This also occurs for any child processes which
        # it launches, presumably due to the inheritance of process handles.
        # Whatever it's doing seriously confuses PowerShell and/or PSReadLine,
        # which seemingly lose track of the console state; subsequent output
        # will often overlap earlier debug output from the installer.
        #
        # The workaround is to launch the installer from a separate console. We
        # do that by launching a cmd instance and then the installer within it.
        # cmd will return the exit code of the installer once it has exited.
        #
        # Also, the argument quoting for cmd looks weird and wrong. It's not;
        # cmd itself is weird and wrong. See its documentation for specifics.
        Write-Progress @WriteProgressParams -Status ('Updating {0}' -f $VsDisplayName) -PercentComplete ($Idx / $VsSetupInstances.Count * 100)
        $VsInstallerArgs = 'update --installPath "{0}" --passive --norestart' -f $VsSetupInstance.InstallationPath
        $CmdArgs = '/D /C ""{0}" {1}"' -f $VsInstallerExe, $VsInstallerArgs
        $VsInstaller = Start-Process -FilePath $env:ComSpec -ArgumentList $CmdArgs -PassThru -Wait

        # If the mutex existed at any point while running this loop the exit
        # code we have from the original installer is not meaningful for the
        # update of Visual Studio itself. We'll output a warning later on.
        $VsInstallerUpdated = $false

        # Set to true initially to avoid the subsequent Write-Progress call on
        # the first (and possibly only) iteration of the loop.
        $VsInstallerMutexCreated = $true
        do {
            # Wait a few seconds in the event the original installer process
            # has exited but the updated installer process hasn't started.
            # While a hack, more durable approaches aren't worth the effort.
            # For further iterations the delay is simply for efficiency.
            Start-Sleep -Seconds 3

            # Try to acquire the Visual Studio Installer mutex. If the named
            # mutex is created then an updated installer is not running. We
            # avoid waiting on the mutex as it's unclear if the mutex already
            # existing may cause problems for the installer (even if unheld).
            [Threading.Mutex]::new($false, 'DevdivInstallerUI', [ref]$VsInstallerMutexCreated).Close()

            if (!$VsInstallerMutexCreated) {
                $VsInstallerUpdated = $true
            }
        } while (!$VsInstallerMutexCreated)

        if ($VsInstallerUpdated) {
            Write-Warning -Message ('{0} update exit code may be unreliable.' -f $VsDisplayName)
        }

        switch ($VsInstaller.ExitCode) {
            3010 { Write-Warning -Message ('{0} successfully updated but requires a reboot.' -f $VsDisplayName) }
            0 { }
            Default {
                Write-Error -Message ('Update of {0} returned exit code: {1}' -f $VsDisplayName, $VsInstaller.ExitCode)
                $VsInstallerStatus = $false
            }
        }
    }

    Write-Progress @WriteProgressParams -Completed

    return $VsInstallerStatus
}

# Update Microsoft Windows
Function Update-Windows {
    [CmdletBinding()]
    Param(
        [Switch]$AcceptAll
    )

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Windows updates.'
    }

    try {
        Import-Module -Name PSWindowsUpdate -ErrorAction Stop -Verbose:$false
    } catch {
        Write-Error -Message 'Unable to install Windows updates as PSWindowsUpdate module not available.'
        return $false
    }

    $Results = Install-WindowsUpdate -AcceptAll:$AcceptAll -IgnoreReboot -NotTitle Silverlight
    if ($Results) {
        return $Results
    }

    return $true
}

Complete-DotFilesSection
