$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Maintenance (Windows)'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Maintenance-Win.format.ps1xml'))

# Update Google Chrome
Function Update-GoogleChrome {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [PSCustomObject])]
    Param()

    if (!(Test-IsAdministrator)) {
        $Msg = 'You must have administrator privileges to perform Chrome updates.'
        if ($WhatIfPreference) {
            Write-Warning -Message $Msg
        } else {
            throw $Msg
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
        $Msg = 'You must have administrator privileges to perform Edge updates.'
        if ($WhatIfPreference) {
            Write-Warning -Message $Msg
        } else {
            throw $Msg
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
    [OutputType([PSCustomObject])]
    Param()

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to update Microsoft Store apps.'
    }

    $Result = [PSCustomObject]@{
        Success     = $false
        ReturnValue = -1
        WhatIf      = $false
    }

    $Namespace = 'root\CIMv2\mdm\dmmap'
    $ClassName = 'MDM_EnterpriseModernAppManagement_AppManagement01'
    $MethodName = 'UpdateScanMethod'

    try {
        $Session = New-CimSession -ErrorAction Stop -Verbose:$false
    } catch {
        throw 'Error creating new WMI session: {0}' -f $PSItem.Exception.Message
    }

    try {
        $Instance = Get-CimInstance -Namespace $Namespace -ClassName $ClassName -ErrorAction Stop
    } catch {
        throw 'Unable to update Microsoft Store apps as {0} WMI class is not available: {1}' -f $ClassName, $PSItem.Exception.Message
    }

    # Modern PowerShell releases throw an exception on trying to instantiate a
    # non-existing class but older releases just return `null`. This includes
    # PowerShell 5.1, which is still the latest inbox version.
    if (!$Instance) {
        throw 'Unable to update Microsoft Store apps as {0} WMI class is not available.' -f $ClassName
    }

    if (!$PSCmdlet.ShouldProcess('Microsoft Store apps', 'Update')) {
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    try {
        $UpdateScan = $Session.InvokeMethod($Namespace, $Instance, $MethodName, $null)
    } catch {
        throw 'Error invoking {0} method of {1} WMI class: {2}' -f $MethodName, $ClassName, $PSItem.Exception.Message
    }

    $Result.ReturnValue = $UpdateScan.ReturnValue.Value
    if ($Result.ReturnValue -eq 0) {
        $Result.Success = $true
    } else {
        Write-Error 'Update of Microsoft Store apps returned: {0}' -f $Result.ReturnValue
    }

    return $Result
}

# Update Microsoft Office (Click-to-Run only)
Function Update-Office {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    $WriteProgressParams = @{ Activity = 'Updating Office' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Success        = $false
        BeforeUpdate   = $null
        AfterUpdate    = $null
        ScenarioResult = [String]::Empty
        WhatIf         = $false
    }

    $UpdateArgs = [String[]]@('/update', 'user', 'updatepromptuser=True')

    $OfficeC2RClient = Join-Path -Path $env:ProgramFiles -ChildPath 'Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe'
    if (!(Test-Path -LiteralPath $OfficeC2RClient -PathType Leaf)) {
        throw 'Unable to update Office as Click-to-Run client not found: {0}' -f $OfficeC2RClient
    }

    $C2RRegPath = 'HKLM:\Software\Microsoft\Office\ClickToRun'
    try {
        $C2RRegKey = Get-Item -LiteralPath $C2RRegPath -ErrorAction Stop
    } catch {
        throw 'Error retrieving Office Click-to-Run registry key: {0}' -f $PSItem.Exception.Message
    }

    $ConfigRegPath = Join-Path -Path $C2RRegPath -ChildPath 'Configuration'
    try {
        $ConfigRegKey = Get-Item -LiteralPath $ConfigRegPath
    } catch {
        throw 'Error retrieving Office Click-to-Run configuration registry key: {0}' -f $PSItem.Exception.Message
    }

    $Version = $null
    $RawVersion = $ConfigRegKey.GetValue('VersionToReport')
    if (![Version]::TryParse($RawVersion, [ref]$Version)) { $Version = $RawVersion }
    $Result.BeforeUpdate = $Version

    if (!$PSCmdlet.ShouldProcess('Office', 'Update')) {
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    Write-Progress @WriteProgressParams
    try {
        Start-Process -FilePath $OfficeC2RClient -ArgumentList $UpdateArgs
    } catch {
        throw 'Error starting Office Click-To-Run client process: {0}' -f $PSItem.Exception.Message
    }

    do {
        Start-Sleep -Seconds 5

        $ExecutingScenario = $C2RRegKey.GetValue('ExecutingScenario')
        if (!$ExecutingScenario) {
            $LastScenario = $C2RRegKey.GetValue('LastScenario')
            $LastScenarioResult = $C2RRegKey.GetValue('LastScenarioResult')
            break
        }

        Write-Progress @WriteProgressParams -Status ('Executing scenario: {0}' -f $ExecutingScenario)
        $TasksRegPath = Join-Path -Path $C2RRegPath -ChildPath ('Scenario\{0}\TasksState' -f $ExecutingScenario)
        $TasksRegKey = Get-Item -LiteralPath $TasksRegPath

        foreach ($Task in $TasksRegKey.GetValueNames()) {
            $TaskName = $Task.Split(':')[0]
            $TaskStatus = $TasksRegKey.GetValue($Task)

            switch ($TaskStatus) {
                'TASKSTATE_CANCELLED' { Write-Warning -Message ('Office update task cancelled in {0} scenario: {1}' -f $ExecutingScenario, $TaskName) }
                'TASKSTATE_FAILED' { Write-Warning -Message ('Office update task failed in {0} scenario: {1}' -f $ExecutingScenario, $TaskName) }
            }
        }
    } while ($true)

    Write-Verbose -Message ('Office update finished {0} scenario with result: {1}' -f $LastScenario, $LastScenarioResult)
    Write-Progress @WriteProgressParams -Completed

    $Result.ScenarioResult = $LastScenarioResult
    if ($Result.ScenarioResult -eq 'Success') { $Result.Success = $true }

    $Version = $null
    $RawVersion = $ConfigRegKey.GetValue('VersionToReport')
    if (![Version]::TryParse($RawVersion, [ref]$Version)) { $Version = $RawVersion }
    $Result.AfterUpdate = $Version

    return $Result
}

# Update Python
Function Update-Python {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name 'pymanager' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Python as pymanager command not found.'
        return
    }

    $UpdatePythonArgs = @('install', '--update')
    if ($WhatIfPreference) {
        $UpdatePythonArgs += '--dry-run'
    }

    if ($WhatIfPreference -or $PSCmdlet.ShouldProcess('Python', 'Update')) {
        Write-Verbose -Message ('Updating Python: pymanager {0}' -f ($UpdatePythonArgs -join ' '))
        $Result = & pymanager @UpdatePythonArgs 2>&1
        return $Result
    }
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
    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateScoop')

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
# https://learn.microsoft.com/en-au/visualstudio/install/use-command-line-parameters-to-install-visual-studio
Function Update-VisualStudio {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to update Visual Studio.'
    }

    try {
        Import-Module -Name 'VSSetup' -ErrorAction Stop -Verbose:$false
    } catch {
        throw 'Unable to update Visual Studio as VSSetup module not available.'
    }

    $WriteProgressParams = @{ Activity = 'Updating Visual Studio' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        # Set to false later if anything goes wrong during the update
        Success      = $true
        BeforeUpdate = @()
        AfterUpdate  = @()
        Errors       = [String[]]@()
        WhatIf       = $false
    }
    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateVisualStudio')

    # Visual Studio Installer is always(?) installed under the 32-bit path
    if ([Environment]::Is64BitOperatingSystem) {
        $ProgramFiles = ${env:ProgramFiles(x86)}
    } else {
        $ProgramFiles = $env:ProgramFiles
    }

    $VsInstallerPath = Join-Path -Path $ProgramFiles -ChildPath 'Microsoft Visual Studio\Installer\vs_installer.exe'
    if (!(Test-Path -LiteralPath $VsInstallerPath -PathType Leaf)) {
        throw 'Unable to update Visual Studio as VS Installer not found: {0}' -f $VsInstallerPath
    }

    $VsSetupInstances = @(Get-VSSetupInstance | Sort-Object -Property 'InstallationVersion')
    if ($VsSetupInstances.Count -eq 0) {
        throw 'Get-VSSetupInstance returned no Visual Studio installations.'
    }

    $VersionToStringMemberParams = @{
        MemberType = 'ScriptMethod'
        Name       = 'ToString'
        Value      = { $this.InstallationVersion }
        Force      = $true
    }

    $Result.BeforeUpdate = $VsSetupInstances
    $Result.BeforeUpdate | Add-Member @VersionToStringMemberParams

    if (!$PSCmdlet.ShouldProcess('Visual Studio', 'Update')) {
        $Result.WhatIf = $true
        return $Result
    }

    $VsUpdateErrors = [Collections.Generic.List[String]]::new()
    for ($Idx = 0; $Idx -lt $VsSetupInstances.Count; $Idx++) {
        $VsSetupInstance = $VsSetupInstances[$Idx]
        $VsDisplayName = $VsSetupInstance.DisplayName

        # Waiting on the Visual Studio Installer to complete is more difficult
        # than at all reasonable. Providing the below parameters and waiting on
        # the process to exit is sufficient *if* the installer itself does not
        # need to be updated. In the latter case, the original setup process
        # will exit while the update continues using the updated installer.
        #
        # Contrary to the official documentation the `--wait` parameter doesn't
        # work, and in fact, doesn't appear to even be a valid option. The best
        # approach I've found is to try to acquire the named mutex used by the
        # installer: `DevdivInstallerUI`. While undocumented and a hack, all of
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
        # do that by launching `cmd` and then the installer within it. `cmd`
        # will return the exit code of the installer once it has exited.
        #
        # Also, the argument quoting for `cmd` looks weird and wrong. It's not;
        # `cmd` itself is weird and wrong. See its documentation for specifics.
        Write-Progress @WriteProgressParams -Status ('Updating {0}' -f $VsDisplayName) -PercentComplete ($Idx / $VsSetupInstances.Count * 100)
        $VsInstallerArgs = 'update --installPath "{0}" --passive --norestart' -f $VsSetupInstance.InstallationPath
        $CmdArgs = '/D /C ""{0}" {1}"' -f $VsInstallerPath, $VsInstallerArgs

        try {
            $VsInstaller = Start-Process -FilePath $env:ComSpec -ArgumentList $CmdArgs -PassThru -Wait
        } catch {
            $Result.Success = $false
            $Msg = 'Failed to start Visual Studio Installer: {0}' -f $PSItem.Exception.Message
            Write-Error -Message $Msg
            $VsUpdateErrors.Add($Msg)
            break
        }

        # If the mutex existed at any point while running this loop the exit
        # code we have from the original installer is not meaningful for the
        # update of Visual Studio itself. We'll output a warning later on.
        $VsInstallerUpdated = $false

        # Set to true initially to avoid the subsequent `Write-Progress` call
        # on the first (and possibly only) iteration of the loop.
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

            if (!$VsInstallerMutexCreated) { $VsInstallerUpdated = $true }
        } while (!$VsInstallerMutexCreated)

        if ($VsInstallerUpdated) {
            Write-Warning -Message ('{0} update exit code may be unreliable.' -f $VsDisplayName)
        }

        switch ($VsInstaller.ExitCode) {
            0 { }
            3010 { Write-Warning -Message ('{0} successfully updated but requires a reboot.' -f $VsDisplayName) }
            Default {
                $Result.Success = $false
                $Msg = 'Update of {0} returned exit code: {1}' -f $VsDisplayName, $VsInstaller.ExitCode
                Write-Error -Message $Msg
                $VsUpdateErrors.Add($Msg)
            }
        }
    }

    $Result.Errors = $VsUpdateErrors.ToArray()

    $VsSetupInstances = @(Get-VSSetupInstance | Sort-Object -Property 'InstallationVersion')
    $Result.AfterUpdate = $VsSetupInstances
    $Result.AfterUpdate | Add-Member @VersionToStringMemberParams

    Write-Progress @WriteProgressParams -Completed
    return $Result
}

# Update Microsoft Windows
Function Update-Windows {
    [CmdletBinding(DefaultParameterSetName = 'Exclude', SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(ParameterSetName = 'Exclude')]
        [ValidateSet('Critical Updates', 'Definition Updates', 'Driver Sets', 'Drivers', 'Feature Packs', 'Security Updates', 'Service Packs', 'Tools', 'Update Rollups', 'Updates', 'Upgrades')]
        [String[]]$ExcludeCategories,

        [Parameter(Mandatory, ParameterSetName = 'Include')]
        [ValidateSet('Critical Updates', 'Definition Updates', 'Driver Sets', 'Drivers', 'Feature Packs', 'Security Updates', 'Service Packs', 'Tools', 'Update Rollups', 'Updates', 'Upgrades')]
        [String[]]$IncludeCategories
    )

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to update Windows.'
    }

    try {
        Import-Module -Name 'PSWindowsUpdate' -ErrorAction Stop -Verbose:$false
    } catch {
        throw 'Unable to update Windows as PSWindowsUpdate module not available.'
    }

    $Result = [PSCustomObject]@{
        # Set to false if any updates fail to download/install
        Success = $true
        Summary = [String]::Empty
        Updates = @()
        WhatIf  = $false
    }
    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateWindows')

    switch ($PSCmdlet.ParameterSetName) {
        'Exclude' { $UpdateParams = @{ 'NotCategory' = $ExcludeCategories } }
        'Include' { $UpdateParams = @{ 'Category' = $IncludeCategories } }
    }

    # `Get-WindowsUpdate` doesn't properly support `-WhatIf`; it will install
    # updates it finds when `-Install` is provided even if `-WhatIf` is set.
    if ($PSCmdlet.ShouldProcess('Windows', 'Update')) {
        $UpdateParams.Add('Install', $true)
        $UpdateParams.Add('AcceptAll', $true)
        $UpdateParams.Add('IgnoreReboot', $true)
    } else {
        $Result.WhatIf = $true
    }

    # TODO: After install three copies of each update are returned?
    $Result.Updates = Get-WindowsUpdate @UpdateParams

    if ($Result.Updates.Count -eq 0) {
        $Result.Summary = 'No updates found'
    } elseif ($Result.WhatIf) {
        $Result.Summary = 'Found {0} updates (scan only)' -f $Result.Updates.Count
    } else {
        $Failed = 0
        $Installed = 0

        foreach ($Update in $Result.Updates) {
            if ($Update.Status -match 'F') { $Failed++ }
            elseif ($Update.Status -match 'I') { $Installed++ }
        }

        if ($Failed -gt 0) { $Result.Success = $false }

        $Result.Summary = '{0} installed, {1} failed, {2} total' -f $Installed, $Failed, $Result.Updates.Count
    }

    return $Result
}

# Update Windows Subsystem for Linux
Function Update-WSL {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param()

    Function Get-WslVersion {
        [CmdletBinding()]
        [OutputType([Void], [PSCustomObject])]
        Param(
            [Switch]$Fatal
        )

        $Result = [PSCustomObject]@{}

        $StatusArgs = [String[]]@('--status')
        $VersionArgs = [String[]]@('--version')

        $DefaultOutputEncoding = [Console]::OutputEncoding

        Write-Verbose -Message ('Retrieving WSL status: wsl {0}' -f ($StatusArgs -join ' '))
        # We can't immediately launch `wsl --version` as if WSL is available
        # but not installed it will prompt the user to press any key to start
        # the install with a 60 second time-out. Instead we can first use `wsl
        # --status` which seems to exit with code 50 when WSL is not installed.
        try {
            [Console]::OutputEncoding = [Text.Encoding]::Unicode
            $null = & wsl @StatusArgs 2>&1
        } catch {
            $Msg = 'Failed to check WSL status: {0}' -f $PSItem.Exception.Message
            if ($Fatal) { throw $Msg } else { Write-Error -Message $Msg; return }
        } finally {
            [Console]::OutputEncoding = $DefaultOutputEncoding
        }

        switch ($LASTEXITCODE) {
            0 { }
            50 {
                $Msg = 'WSL is not installed.'
                if ($Fatal) { throw $Msg } else { Write-Error -Message $Msg; return }
            }
            default {
                $Msg = 'Unknown exit code return by WSL: {0}' -f $LASTEXITCODE
                if ($Fatal) { throw $Msg } else { Write-Error -Message $Msg; return }
            }
        }

        Write-Verbose -Message ('Retrieving WSL version: wsl {0}' -f ($VersionArgs -join ' '))
        try {
            [Console]::OutputEncoding = [Text.Encoding]::Unicode
            $WslVersion = & wsl @VersionArgs
        } catch {
            $Msg = 'Failed to check WSL version: {0}' -f $PSItem.Exception.Message
            if ($Fatal) { throw $Msg } else { Write-Error -Message $Msg; return }
        } finally {
            [Console]::OutputEncoding = $DefaultOutputEncoding
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warning -Message 'WSL returned non-zero exit code on requesting version details: {0}' -f $LASTEXITCODE
        }

        foreach ($Line in $WslVersion) {
            if ([String]::IsNullOrWhiteSpace($Line)) { continue }

            if ($Line -notmatch '^([A-Za-z0-9]+) version: (.+)') {
                Write-Warning -Message ('Unable to parse line in version output: {0}' -f $Line)
                continue
            }

            $Component = $Matches[1]
            $RawVersion = $Matches[2]

            $Version = $null
            if (![Version]::TryParse($RawVersion, [ref]$Version)) { $Version = $RawVersion }

            $Result | Add-Member -MemberType NoteProperty -Name $Component -Value $Version
        }

        if ($Result.PSObject.Properties.Name -contains 'WSL') {
            $Result | Add-Member -MemberType ScriptMethod -Name 'ToString' -Value { $this.WSL } -Force
        } else {
            Write-Warning -Message 'No WSL version identified in version output.'
        }

        return $Result
    }

    if (!(Get-Command -Name 'wsl' -ErrorAction Ignore)) {
        throw 'Unable to update WSL as wsl command not found.'
    }

    $Result = [PSCustomObject]@{
        Success      = $false
        BeforeUpdate = [String[]]@()
        AfterUpdate  = [String[]]@()
        Output       = [String[]]@()
        ExitCode     = -1
        WhatIf       = $false
    }
    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateWSL')

    $UpdateArgs = [String[]]@('--update')

    $Result.BeforeUpdate = Get-WslVersion -Fatal

    if (!$PSCmdlet.ShouldProcess('WSL', 'Update')) {
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    Write-Verbose -Message ('Updating WSL: wsl {0}' -f ($UpdateArgs -join ' '))
    $DefaultOutputEncoding = [Console]::OutputEncoding

    try {
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        $Result.Output = [String[]]@(& wsl @UpdateArgs 2>&1)
        $Result.ExitCode = $LASTEXITCODE

        if ($Result.ExitCode -ne 0) {
            Write-Error -Message ('WSL returned non-zero exit code on performing update: {0}' -f $Result.ExitCode)
        }
    } catch {
        $Msg = 'Failed to start WSL update: {0}' -f $PSItem.Exception.Message
        $Result.Output = [String[]]@($Msg)
        Write-Eror -Message $Msg
    } finally {
        [Console]::OutputEncoding = $DefaultOutputEncoding
    }

    $Result.AfterUpdate = Get-WslVersion
    if ($null -ne $Result.AfterUpdate) {
        if ($Result.ExitCode -eq 0) { $Result.Success = $true }
    } else {
        Write-Error -Message 'Unable to detect WSL version after updating.'
    }

    return $Result
}

Complete-DotFilesSection
