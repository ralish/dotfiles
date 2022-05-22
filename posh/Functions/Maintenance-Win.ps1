if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

if (!(Test-IsWindows)) {
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing maintenance functions (Windows only) ...')

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
    [CmdletBinding()]
    Param(
        [Switch]$CaptureOutput,

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

    [String[]]$UpdateArgs = 'update', '--quiet'
    [String[]]$UpdateAppsArgs = 'update', '*', '--quiet'
    [String[]]$CleanupArgs = 'cleanup', '-k', '*'

    Write-Progress @WriteProgressParams -Status 'Updating module & repository' -PercentComplete 1
    Write-Verbose -Message ('Updating Scoop: scoop {0}' -f ($UpdateArgs -join ' '))
    if ($CaptureOutput) {
        $ScoopOutput = & scoop @UpdateArgs 6>&1
    } else {
        & scoop @UpdateArgs
        Write-Host
    }

    Write-Progress @WriteProgressParams -Status 'Updating apps' -PercentComplete 20
    Write-Verbose -Message ('Updating Scoop apps: scoop {0}' -f ($UpdateAppsArgs -join ' '))
    if ($CaptureOutput) {
        $ScoopOutput += & scoop @UpdateAppsArgs 6>&1
    } else {
        & scoop @UpdateAppsArgs
        Write-Host
    }

    Write-Progress @WriteProgressParams -Status 'Uninstalling obsolete apps' -PercentComplete 80
    Write-Verbose -Message ('Uninstalling obsolete Scoop apps: scoop {0}' -f ($CleanupArgs -join ' '))
    if ($CaptureOutput) {
        $ScoopOutput += & scoop @CleanupArgs 6>&1
    } else {
        & scoop @CleanupArgs
        Write-Host
    }

    Write-Progress @WriteProgressParams -Completed

    if ($CaptureOutput) {
        return $ScoopOutput
    }
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
        return
    }

    Test-ModuleAvailable -Name VSSetup

    $VsSetupInstances = @(Get-VSSetupInstance | Sort-Object -Property InstallationVersion)
    if ($VsSetupInstances.Count -eq 0) {
        Write-Error -Message 'Get-VSSetupInstance returned no instances.'
        return
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

        # Waiting on the Visual Studio Installer to complete is far more difficult
        # than at all reasonable. Providing the below parameters and waiting on the
        # process to exit is sufficient *if* the installer itself does not need to
        # be updated. In the latter case however, the original setup process will
        # exit while the update continues in the newly launched updated installer.
        #
        # Contrary to what the official documentation states the "--wait" parameter
        # does not work; in fact, it doesn't appear to even be a valid option. The
        # best approach I've found is to try to acquire the named mutex used by the
        # installer: DevdivInstallerUI. This is obviously undocumented and a hack,
        # but all of the other approaches I've found have more serious downsides.
        # We use this approach later after the original setup process has exited.
        #
        # Further, when launched via a console application the installer will spam
        # the terminal with various debug output, even if running in quiet mode. I
        # can't find any command-line parameter to suppress it, and redirecting the
        # process output streams doesn't seem to work either. Given it's a GUI app,
        # I suspect it's doing something nefarious if it detects it's launched via
        # a console environment. This also occurs for child processes it launches,
        # presumably due to process handle inheritance. Whatever it's doing really
        # confuses PowerShell and/or PSReadline, seemingly causing it to lose track
        # of the console state; subsequent output will often overlap earlier debug
        # output from the installer.
        #
        # The filthy but workable solution is to launch the install from a separate
        # console, but as the executable is a GUI app, we have to do that by first
        # launching a separate console instance and then launching the installer
        # within it. We use cmd for this purpose and have it return the exit code
        # of the Visual Studio Installer as soon as it completes.
        #
        # And yes, the command-line argument quoting for cmd looks weird and wrong.
        # It's not; cmd itself is weird and wrong. See its help for the specifics.
        Write-Progress @WriteProgressParams -Status ('Updating {0}' -f $VsDisplayName) -PercentComplete ($Idx / $VsSetupInstances.Count * 100)
        $VsInstallerArgs = 'update --installPath "{0}" --passive --norestart' -f $VsSetupInstance.InstallationPath
        $CmdArgs = '/D /C ""{0}" {1}"' -f $VsInstallerExe, $VsInstallerArgs
        $VsInstaller = Start-Process -FilePath $env:ComSpec -ArgumentList $CmdArgs -PassThru -Wait

        # If the mutex existed at any point while running this loop, the exit code
        # we have from the original installer is not meaningful for the update of
        # Visual Studio itself, and we'll output a warning later on.
        $VsInstallerUpdated = $false

        # Set to true initially to avoid the subsequent Write-Progress call on the
        # first iteration of the loop (and possibly the only iteration).
        $VsInstallerMutexCreated = $true
        do {
            # Wait a few seconds in case the original installer process has exited
            # but the updated installer process has not yet started. I'm unsure if
            # this is actually a possible scenario but am being cautious. Obviously
            # a not particularly durable hack, but more durable approaches aren't
            # worth the effort. For further iterations the delay is for efficiency.
            Start-Sleep -Seconds 3

            # Try to acquire the Visual Studio Installer mutex. If the named mutex
            # is created, then an updated installer is not running. If it exists, a
            # Visual Studio Installer is running. We avoid actually waiting on the
            # mutex as it's unclear if it existing, even if not held, causes any
            # problems for the installer.
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
        return
    }

    $Results = Install-WindowsUpdate -AcceptAll:$AcceptAll -IgnoreReboot -NotTitle Silverlight
    if ($Results) {
        return $Results
    }
}
