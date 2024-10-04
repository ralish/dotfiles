$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Maintenance (Windows)'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Update Google Chrome
Function Update-GoogleChrome {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [PSCustomObject])]
    Param()

    if (!(Test-IsAdministrator)) {
        $Message = 'You must have administrator privileges to perform Chrome updates.'
        if ($WhatIfPreference) {
            Write-Warning -Message $Message
        } else {
            throw $Message
        }
    }

    if ([Environment]::Is64BitOperatingSystem) {
        $ProgramFiles = ${env:ProgramFiles(x86)}
    } else {
        $ProgramFiles = $env:ProgramFiles
    }

    $GoogleUpdatePath = Join-Path -Path $ProgramFiles -ChildPath 'Google\Update\GoogleUpdate.exe'
    if (!(Test-Path -LiteralPath $GoogleUpdatePath -PathType Leaf)) {
        Write-Error -Message 'Unable to install Chrome updates as Google Update not found.'
        return
    }

    $GoogleUpdateArgs = @(
        '/silent',
        '/install',
        # GUID corresponds to Stable channel
        'appguid={8A69D345-D564-463C-AFF1-A69D9E530F96}&appname=Google%20Chrome&needsadmin=True'
    )

    $Result = [PSCustomObject]@{
        Status          = $true
        Version         = $null
        PreviousVersion = $null
        Updated         = $false
    }

    # Deliberately using $env:ProgramFiles as Chrome uses the 64-bit path on
    # 64-bit systems while Google Update will always uses the 32-bit path.
    $ChromePath = Join-Path -Path $env:ProgramFiles -ChildPath 'Google\Chrome\Application\chrome.exe'

    try {
        $Chrome = Get-Item -LiteralPath $ChromePath -ErrorAction Stop
        $Result.PreviousVersion = $Chrome.VersionInfo.ProductVersion
    } catch {
        $Result.PreviousVersion = 'None found'
    }

    if (!$PSCmdlet.ShouldProcess('Google Chrome', 'Update')) {
        return
    }

    $GoogleUpdate = Start-Process -FilePath $GoogleUpdatePath -ArgumentList $GoogleUpdateArgs -PassThru -Wait

    if ($GoogleUpdate.ExitCode -ne 0) {
        Write-Error -Message ('Google Update returned exit code: {0}' -f $GoogleUpdate.ExitCode)
        $Result.Status = $false
    }

    try {
        $Chrome = Get-Item -LiteralPath $ChromePath -ErrorAction Stop
        $Result.Version = $Chrome.VersionInfo.ProductVersion
    } catch {
        $Result.Version = 'None found'
    }

    return $Result
}

# Update Microsoft Edge
#
# Deploy Microsoft Edge with Windows 10 updates
# https://learn.microsoft.com/en-au/deployedge/deploy-edge-with-windows-10-updates
Function Update-MicrosoftEdge {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [PSCustomObject])]
    Param()

    if (!(Test-IsAdministrator)) {
        $Message = 'You must have administrator privileges to perform Edge updates.'
        if ($WhatIfPreference) {
            Write-Warning -Message $Message
        } else {
            throw $Message
        }
    }

    if ([Environment]::Is64BitOperatingSystem) {
        $ProgramFiles = ${env:ProgramFiles(x86)}
    } else {
        $ProgramFiles = $env:ProgramFiles
    }

    $EdgeUpdatePath = Join-Path -Path $ProgramFiles -ChildPath 'Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe'
    if (!(Test-Path -LiteralPath $EdgeUpdatePath -PathType Leaf)) {
        Write-Error -Message 'Unable to install Edge updates as Edge Update not found.'
        return
    }

    $EdgeUpdateArgs = @(
        '/silent',
        '/install',
        # GUID corresponds to Stable channel
        'appguid={56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}&appname=Microsoft%20Edge&needsadmin=True'
    )

    $Result = [PSCustomObject]@{
        Status          = $true
        Version         = $null
        PreviousVersion = $null
        Updated         = $false
    }

    $EdgePath = Join-Path -Path $ProgramFiles -ChildPath 'Microsoft\Edge\Application\msedge.exe'

    try {
        $Edge = Get-Item -LiteralPath $EdgePath -ErrorAction Stop
        $Result.PreviousVersion = $Edge.VersionInfo.ProductVersion
    } catch {
        $Result.PreviousVersion = 'None found'
    }

    if (!$PSCmdlet.ShouldProcess('Microsoft Edge', 'Update')) {
        return
    }

    $EdgeUpdate = Start-Process -FilePath $EdgeUpdatePath -ArgumentList $EdgeUpdateArgs -PassThru -Wait

    if ($EdgeUpdate.ExitCode -ne 0) {
        Write-Error -Message ('Edge Update returned exit code: {0}' -f $EdgeUpdate.ExitCode)
        $Result.Status = $false
    }

    try {
        $Edge = Get-Item -LiteralPath $EdgePath -ErrorAction Stop
        $Result.Version = $Edge.VersionInfo.ProductVersion
    } catch {
        $Result.Version = 'None found'
    }

    return $Result
}

# Update Microsoft Store apps
Function Update-MicrosoftStore {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Boolean])]
    Param()

    if (!(Test-IsAdministrator)) {
        $Message = 'You must have administrator privileges to perform Microsoft Store updates.'
        if ($WhatIfPreference) {
            Write-Warning -Message $Message
        } else {
            throw $Message
        }
    }

    if (!$PSCmdlet.ShouldProcess('Microsoft Store', 'Update')) {
        return
    }

    $Namespace = 'root\CIMv2\mdm\dmmap'
    $Class = 'MDM_EnterpriseModernAppManagement_AppManagement01'
    $Method = 'UpdateScanMethod'

    $Session = New-CimSession
    $Instance = Get-CimInstance -Namespace $Namespace -ClassName $Class
    $UpdateScan = $Session.InvokeMethod($Namespace, $Instance, $Method, $null)

    $Result = $true
    if ($UpdateScan.ReturnValue.Value -ne 0) {
        Write-Error -Message ('Update of Microsoft Store apps returned: {0}' -f $UpdateScan.ReturnValue.Value)
        $Result = $false
    }

    return $Result
}

# Update Microsoft Office (Click-to-Run only)
Function Update-Office {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [PSCustomObject])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Test-IsAdministrator)) {
        $Message = 'You must have administrator privileges to perform Office updates.'
        if ($WhatIfPreference) {
            Write-Warning -Message $Message
        } else {
            throw $Message
        }
    }

    $OfficeC2RClient = Join-Path -Path $env:ProgramFiles -ChildPath 'Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe'
    if (!(Test-Path -LiteralPath $OfficeC2RClient -PathType Leaf)) {
        Write-Error -Message 'Unable to install Office updates as Click-to-Run client not found.'
        return
    }

    $WriteProgressParams = @{
        Activity = 'Updating Office'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Status          = $null
        Version         = $null
        PreviousVersion = $null
        Updated         = $false
    }

    $OfficeRegPath = 'HKLM:\Software\Microsoft\Office\ClickToRun'
    $OfficeRegKey = Get-Item -LiteralPath $OfficeRegPath

    $ConfigRegPath = Join-Path -Path $OfficeRegPath -ChildPath 'Configuration'
    $ConfigRegKey = Get-Item -LiteralPath $ConfigRegPath

    $RawVersion = $ConfigRegKey.GetValue('VersionToReport')
    $Version = $null
    if (![Version]::TryParse($RawVersion, [ref]$Version)) {
        $Version = $RawVersion
    }
    $Result.PreviousVersion = $Version

    if (!$PSCmdlet.ShouldProcess('Office', 'Update')) {
        return $Result
    }

    Write-Progress @WriteProgressParams
    & $OfficeC2RClient /update user updatepromptuser=True
    Start-Sleep -Seconds 3

    do {
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

    $RawVersion = $ConfigRegKey.GetValue('VersionToReport')
    $Version = $null
    if (![Version]::TryParse($RawVersion, [ref]$Version)) {
        $Version = $RawVersion
    }
    $Result.Version = $Version

    if ($Result.Version -ne $Result.PreviousVersion) {
        $Result.Updated = $true
    }

    $Result.Status = $LastScenarioResult

    Write-Verbose -Message ('Office update finished {0} scenario with result: {1}' -f $LastScenario, $LastScenarioResult)
    Write-Progress @WriteProgressParams -Completed

    return $Result
}

# Update Scoop & installed apps
Function Update-Scoop {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [PSCustomObject])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Get-Command -Name 'scoop' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Scoop as scoop command not found.'
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
        Scoop   = $null
        Apps    = $null
        Cleanup = $null
    }

    [String[]]$UpdateScoopArgs = 'update', '--quiet'
    [String[]]$UpdateAppsArgs = 'update', '*', '--quiet'
    [String[]]$CleanupArgs = 'cleanup', '*', '--cache'
    if ($WhatIfPreference) {
        $UpdateAppsArgs = 'status', '--local'
    }

    # There's no simple way to disable the output of the download progress bar
    # during Scoop updates. It adds a lot of noise to the captured output, so
    # we filter out relevant lines using a regular expression match.
    $ProgressBarRegex = '\[=*(> *)?\] +[0-9]{1,3}%'

    if ($WhatIfPreference -or $PSCmdlet.ShouldProcess('Scoop', 'Update')) {
        Write-Progress @WriteProgressParams -Status 'Updating Scoop' -PercentComplete 1
        Write-Verbose -Message ('Updating Scoop: scoop {0}' -f ($UpdateScoopArgs -join ' '))
        $Result.Scoop = & scoop @UpdateScoopArgs 6>&1
    }

    if ($WhatIfPreference -or $PSCmdlet.ShouldProcess('Scoop apps', 'Update')) {
        Write-Progress @WriteProgressParams -Status 'Updating apps' -PercentComplete 20
        Write-Verbose -Message ('Updating apps: scoop {0}' -f ($UpdateAppsArgs -join ' '))
        $Result.Apps = & scoop @UpdateAppsArgs 6>&1 | Where-Object { $_ -notmatch $ProgressBarRegex }
    }

    if ($PSCmdlet.ShouldProcess('Scoop obsolete files', 'Remove')) {
        Write-Progress @WriteProgressParams -Status 'Cleaning-up obsolete files' -PercentComplete 80
        Write-Verbose -Message ('Cleaning-up obsolete files: scoop {0}' -f ($CleanupArgs -join ' '))
        $Result.Cleanup = & scoop @CleanupArgs 6>&1
    }

    Write-Progress @WriteProgressParams -Completed

    return $Result
}

# Update Microsoft Visual Studio
#
# Use command-line parameters to install, update, and manage Visual Studio
# https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio
Function Update-VisualStudio {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [PSCustomObject])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Test-IsAdministrator)) {
        $Message = 'You must have administrator privileges to perform Visual Studio updates.'
        if ($WhatIfPreference) {
            Write-Warning -Message $Message
        } else {
            throw $Message
        }
    }

    if ([Environment]::Is64BitOperatingSystem) {
        $ProgramFiles = ${env:ProgramFiles(x86)}
    } else {
        $ProgramFiles = $env:ProgramFiles
    }

    $VsInstallerExe = Join-Path -Path $ProgramFiles -ChildPath 'Microsoft Visual Studio\Installer\vs_installer.exe'
    if (!(Test-Path -LiteralPath $VsInstallerExe -PathType Leaf)) {
        Write-Error -Message 'Unable to update Visual Studio as VSInstaller not found.'
        return
    }

    Test-ModuleAvailable -Name 'VSSetup'

    $VsSetupInstances = @(Get-VSSetupInstance | Sort-Object -Property 'InstallationVersion')
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

    $Result = [PSCustomObject]@{
        # Set to false if an unexpected exit code is returned for any update
        Status           = $true
        Versions         = @()
        PreviousVersions = $VsSetupInstances
        Updated          = $false
    }

    $VersionToString = { $this.InstallationVersion }
    $Result.PreviousVersions | Add-Member -MemberType ScriptMethod -Name ToString -Value $VersionToString -Force

    if (!$PSCmdlet.ShouldProcess('Visual Studio', 'Update')) {
        return $Result
    }

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
            [Threading.Mutex]::new($false, 'DevdivInstallerUI', [Ref]$VsInstallerMutexCreated).Close()

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
                $Result.Status = $false
            }
        }
    }

    $VsSetupInstances = @(Get-VSSetupInstance | Sort-Object -Property 'InstallationVersion')
    $Result.Versions = $VsSetupInstances
    $Result.Versions | Add-Member -MemberType ScriptMethod -Name ToString -Value $VersionToString -Force

    foreach ($UpdatedInstance in $VsSetupInstances) {
        $PreviousInstance = $Result.PreviousVersions | Where-Object InstanceId -EQ $UpdatedInstance.InstanceId
        if ($PreviousInstance.InstallationVersion -ne $UpdatedInstance.InstallationVersion) {
            $Result.Updated = $true
            break
        }
    }

    Write-Progress @WriteProgressParams -Completed

    return $Result
}

# Update Microsoft Windows
Function Update-Windows {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    [CmdletBinding(SupportsShouldProcess)]
    #[OutputType([Boolean], [PSWindowsUpdate.WindowsUpdateJob[]])]
    Param(
        [Switch]$AcceptAll
    )

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Windows updates.'
    }

    try {
        Import-Module -Name 'PSWindowsUpdate' -ErrorAction Stop -Verbose:$false
    } catch {
        Write-Error -Message 'Unable to install Windows updates as PSWindowsUpdate module not available.'
        return $false
    }

    # TODO: PSWindowsUpdate seems to return three copies of all results?
    $Results = $false
    if ($WhatIfPreference) {
        $Results = Get-WindowsUpdate -AcceptAll:$AcceptAll -IgnoreReboot -NotTitle 'Silverlight'
    } elseif ($PSCmdlet.ShouldProcess('Windows', 'Update')) {
        $Results = Install-WindowsUpdate -AcceptAll:$AcceptAll -IgnoreReboot -NotTitle 'Silverlight'
    }

    if ($Results) {
        return $Results
    }

    return $true
}

# Update Windows Subsystem for Linux
Function Update-WSL {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [PSCustomObject])]
    Param()

    Function Get-WslVersion {
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        Param()

        $Result = [PSCustomObject]@{}
        $DefaultOutputEncoding = [Console]::OutputEncoding

        try {
            [Console]::OutputEncoding = [Text.Encoding]::Unicode
            $WslVersion = & wsl --version

            foreach ($Line in $WslVersion) {
                if ([String]::IsNullOrWhiteSpace($Line)) {
                    continue
                }

                if ($Line -notmatch '^([A-Za-z0-9]+) version: (.+)') {
                    Write-Warning -Message ('Unable to parse line in version output: {0}' -f $Line)
                    continue
                }

                $Component = $Matches[1]
                $RawVersion = $Matches[2]

                $Version = $null
                if (![Version]::TryParse($RawVersion, [ref]$Version)) {
                    $Version = $RawVersion
                }

                $Result | Add-Member -MemberType NoteProperty -Name $Component -Value $Version
            }
        } finally {
            [Console]::OutputEncoding = $DefaultOutputEncoding
        }

        if ($Result.PSObject.Properties.Name -contains 'WSL') {
            $Result | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.WSL } -Force
        } else {
            Write-Warning -Message 'No WSL version identified in version output.'
        }

        return $Result
    }

    if (!(Get-Command -Name 'wsl' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update WSL as wsl command not found.'
        return
    }

    $Result = [PSCustomObject]@{
        Status          = $null
        Version         = $null
        PreviousVersion = $null
        Updated         = $false
    }

    $Result.PreviousVersion = Get-WslVersion

    if (!$PSCmdlet.ShouldProcess('WSL', 'Update')) {
        return $Result
    }

    $DefaultOutputEncoding = [Console]::OutputEncoding
    try {
        Write-Verbose -Message 'Updating WSL: wsl --update'
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        $Result.Status = & wsl --update
    } finally {
        [Console]::OutputEncoding = $DefaultOutputEncoding
    }

    $Result.Version = Get-WslVersion

    foreach ($Component in $Result.Version.PSObject.Properties.Name) {
        if ($Component -notin $Result.PreviousVersion.PSObject.Properties.Name) {
            $Result.Updated = $true
            break
        }

        if ($Result.Version.$Component -ne $Result.PreviousVersion.$Component) {
            $Result.Updated = $true
            break
        }
    }

    return $Result
}

Complete-DotFilesSection
