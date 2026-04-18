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
#
# Chromium Updater Functional Specification
# https://chromium.googlesource.com/chromium/src/+/HEAD/docs/updater/functional_spec.md#Updates
Function Update-Chrome {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateSet('Stable', 'Beta', 'Dev', 'Canary')]
        [String]$UpdateChannel = 'Stable',

        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    Function Release-ComObjects {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
        [CmdletBinding()]
        [OutputType([Void])]
        Param()

        if ($NextVersionWeb) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($NextVersionWeb) }
        if ($CurrentVersionWeb) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($CurrentVersionWeb) }
        if ($AppUpdate) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($AppUpdate) }
        if ($AppBundle) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($AppBundle) }
        if ($GoogleUpdate) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($GoogleUpdate) }
    }

    $WriteProgressParams = @{ Activity = 'Updating Chrome' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Success       = $false
        BeforeUpdate  = $null
        AfterUpdate   = $null
        UpdateState   = [String]::Empty
        UpdateStateId = -1
        WhatIf        = $false
    }

    switch ($UpdateChannel) {
        Stable { $AppId = '{8A69D345-D564-463c-AFF1-A69D9E530F96}' }
        Beta { $AppId = '{8237E44A-0054-442C-B6B6-EA0509993955}' }
        Dev { $AppId = '{401C381F-E0DE-4B85-8BD8-3F3F14FBDA57}' }
        Canary { $AppId = '{4EA16AC7-FD5A-47C3-875B-DBF4A2008C20}' }
    }

    # https://github.com/chromium/chromium/blob/main/chrome/updater/win/win_constants.h
    $ComObjectName = 'GoogleUpdate.Update3WebMachine'

    # https://github.com/chromium/chromium/blob/main/chrome/updater/app/server/win/updater_legacy_idl.template
    $UpdateStates = @{
        1  = 'Initialising'
        2  = 'Waiting to check for update'
        3  = 'Checking for update'
        4  = 'Update available'
        5  = 'Waiting to download'
        6  = 'Retrying download'
        7  = 'Downloading'
        8  = 'Download complete'
        9  = 'Extracting'
        10 = 'Applying differential patch'
        11 = 'Ready to install'
        12 = 'Waiting to install'
        13 = 'Installing'
        14 = 'Install complete'
        15 = 'Paused'
        16 = 'No update'
        17 = 'Error'
    }

    # So we don't free someone else's COM objects in the (extremely unlikely)
    # case that they're using the same variable names in a parent scope.
    $GoogleUpdate = $null
    $AppBundle = $null
    $AppUpdate = $null
    $CurrentVersionWeb = $null
    $NextVersionWeb = $null

    # Errors returned from COM objects are surfaced by the .NET runtime as
    # generic `RuntimeException`s (0x80131501 - COR_E_SYSTEM), requiring
    # inspection of the exception message to determine what went wrong.

    try {
        $GoogleUpdate = New-Object -ComObject $ComObjectName
    } catch {
        Release-ComObjects

        switch -RegEx ($PSItem.Exception.Message) {
            # REGDB_E_CLASSNOTREG
            '\b0x80040154\b' { throw 'Unable to update Chrome as Google Update is not available.' }
        }

        throw 'Google Update COM object failed to activate: {0}' -f $PSItem.Exception.Message
    }

    try {
        $AppBundle = $GoogleUpdate.createAppBundleWeb()
    } catch {
        Release-ComObjects
        throw 'Google Update failed to create Chrome app bundle: {0}' -f $PSItem.Exception.Message
    }

    try {
        $AppBundle.initialize()
    } catch {
        Release-ComObjects
        throw 'Chrome app bundle failed to initialise: {0}' -f $PSItem.Exception.Message
    }

    try {
        $AppBundle.createInstalledApp($AppId)
    } catch {
        Release-ComObjects

        switch -RegEx ($PSItem.Exception.Message) {
            # GOOPDATE_E_APP_UPDATE_DISABLED_BY_POLICY
            '\b0x80040813\b' { throw 'Google Update reported updates are disabled by policy.' }
            # GOOPDATE_E_APP_UPDATE_DISABLED_BY_POLICY_MANUAL
            '\b0x8004081f\b' { throw 'Google Update reported updates are disabled by policy (manual).' }
            # GOOPDATE_E_APP_USING_EXTERNAL_UPDATER
            '\b0xA043081D\b' { throw 'Google Update reported an update is already in-progress.' }
        }

        throw 'Chrome app bundle failed to create installed app: {0}' -f $PSItem.Exception.Message
    }

    try {
        # Parameter is index of created app
        $AppUpdate = $AppBundle.appWeb(0)
    } catch {
        Release-ComObjects
        throw 'Failed to retrieve app instance from Chrome app bundle: {0}' -f $PSItem.Exception.Message
    }

    try {
        $CurrentVersionWeb = $AppUpdate.currentVersionWeb
        $Result.BeforeUpdate = $CurrentVersionWeb.version
    } catch {
        Release-ComObjects
        throw 'Failed to retrieve current version from Chrome app bundle: {0}' -f $PSItem.Exception.Message
    }

    if (!$PSCmdlet.ShouldProcess('Chrome', 'Update')) {
        Release-ComObjects
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    $MaxWaitTime = 300 # 5 mins
    $WaitTime = [Diagnostics.Stopwatch]::StartNew()

    do {
        $LastUpdateStateId = $AppUpdate.currentState.stateValue
        if ($UpdateStates.ContainsKey($LastUpdateStateId)) {
            $LastUpdateState = $UpdateStates[$LastUpdateStateId]
        } else {
            $LastUpdateState = 'Unknown'
        }

        $ElapsedSeconds = [Int]($WaitTime.ElapsedMilliseconds / 1000)
        $StatusMsg = 'Update state: {0} (Waited {1} secs / time-out: {2} secs) ...' -f $LastUpdateState, $ElapsedSeconds, $MaxWaitTime
        Write-Progress @WriteProgressParams -Status $StatusMsg

        switch ($LastUpdateStateId) {
            # Initialising
            1 {
                try {
                    $AppBundle.checkForUpdate()
                } catch {
                    Release-ComObjects
                    throw 'Failed to trigger Chrome update check: {0}' -f $PSItem.Exception.Message
                }
            }

            # Update available
            4 {
                try {
                    $AppBundle.download()
                } catch {
                    Release-ComObjects
                    throw 'Failed to trigger Chrome update download: {0}' -f $PSItem.Exception.Message
                }
            }

            # Ready to install
            11 {
                try {
                    $AppBundle.install()
                } catch {
                    Release-ComObjects
                    throw 'Failed to trigger Chrome update install: {0}' -f $PSItem.Exception.Message
                }
            }
        }

        # IDs >= 14 are final states
        if ($LastUpdateStateId -ge 14) {
            $Result.UpdateState = $LastUpdateState
            $Result.UpdateStateId = $LastUpdateStateId
            break
        }

        Start-Sleep -Seconds 1
    } while ($ElapsedSeconds -lt $MaxWaitTime)

    $WaitTime.Stop()
    Write-Progress @WriteProgressParams -Completed

    switch ($Result.UpdateStateId) {
        # Install complete
        14 {
            try {
                $NextVersionWeb = $AppUpdate.nextVersionWeb
                $Result.AfterUpdate = $NextVersionWeb.version
                $Result.Success = $true
            } catch {
                Write-Error -Message ('Failed to retrieve new version from Chrome app bundle: {0}' -f $PSItem.Exception.Message)
            }
        }

        # Paused
        15 { Write-Warning -Message 'Google Update reported the update is paused.' }

        # No update
        16 {
            $Result.AfterUpdate = $Result.BeforeUpdate
            $Result.Success = $true
        }

        # Error
        17 { Write-Error -Message 'Google Update reported an error occurred.' }

        # Timeout
        -1 {
            $LastUpdateStateMsg = 'Last update state: {1} [ID: {2}]' -f $LastUpdateState, $LastUpdateStateId
            Write-Warning -Message ('Gave-up waiting on Chrome after {0} secs ({1})' -f $MaxWaitTime, $LastUpdateStateMsg)
        }

        # Unknown state ID
        default { Write-Error -Message ('Google Update reported an unknown state ID: {0}' -f $Result.UpdateStateId) }
    }

    Release-ComObjects
    return $Result
}

# Update Microsoft Edge
Function Update-Edge {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateSet('Stable', 'Beta', 'Dev', 'Canary')]
        [String]$UpdateChannel = 'Stable',

        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    Function Release-ComObjects {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
        [CmdletBinding()]
        [OutputType([Void])]
        Param()

        if ($NextVersionWeb) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($NextVersionWeb) }
        if ($CurrentVersionWeb) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($CurrentVersionWeb) }
        if ($AppUpdate) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($AppUpdate) }
        if ($AppBundle) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($AppBundle) }
        if ($EdgeUpdate) { $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($EdgeUpdate) }
    }

    $WriteProgressParams = @{ Activity = 'Updating Edge' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Success       = $false
        BeforeUpdate  = $null
        AfterUpdate   = $null
        UpdateState   = [String]::Empty
        UpdateStateId = -1
        WhatIf        = $false
    }

    switch ($UpdateChannel) {
        Stable { $AppId = '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' }
        Beta { $AppId = '{2CD8A007-E189-409D-A2C8-9AF4EF3C72AA}' }
        Dev { $AppId = '{0D50BFEC-CD6A-4F9A-964C-C7416E3ACB10}' }
        Canary { $AppId = '{65C35B14-6C1D-4122-AC46-7148CC9D6497}' }
    }

    # https://github.com/chromium/chromium/blob/main/chrome/updater/win/win_constants.h
    $ComObjectName = 'MicrosoftEdgeUpdate.Update3WebMachine'

    # https://github.com/chromium/chromium/blob/main/chrome/updater/app/server/win/updater_legacy_idl.template
    $UpdateStates = @{
        1  = 'Initialising'
        2  = 'Waiting to check for update'
        3  = 'Checking for update'
        4  = 'Update available'
        5  = 'Waiting to download'
        6  = 'Retrying download'
        7  = 'Downloading'
        8  = 'Download complete'
        9  = 'Extracting'
        10 = 'Applying differential patch'
        11 = 'Ready to install'
        12 = 'Waiting to install'
        13 = 'Installing'
        14 = 'Install complete'
        15 = 'Paused'
        16 = 'No update'
        17 = 'Error'
    }

    # So we don't free someone else's COM objects in the (extremely unlikely)
    # case that they're using the same variable names in a parent scope.
    $EdgeUpdate = $null
    $AppBundle = $null
    $AppUpdate = $null
    $CurrentVersionWeb = $null
    $NextVersionWeb = $null

    # Errors returned from COM objects are surfaced by the .NET runtime as
    # generic `RuntimeException`s (0x80131501 - COR_E_SYSTEM), requiring
    # inspection of the exception message to determine what went wrong.

    try {
        $EdgeUpdate = New-Object -ComObject $ComObjectName
    } catch {
        Release-ComObjects

        switch -RegEx ($PSItem.Exception.Message) {
            # REGDB_E_CLASSNOTREG
            '\b0x80040154\b' { throw 'Unable to update Edge as Edge Update is not available.' }
        }

        throw 'Edge Update COM object failed to activate: {0}' -f $PSItem.Exception.Message
    }

    try {
        $AppBundle = $EdgeUpdate.createAppBundleWeb()
    } catch {
        Release-ComObjects
        throw 'Edge Update failed to create Edge app bundle: {0}' -f $PSItem.Exception.Message
    }

    try {
        $AppBundle.initialize()
    } catch {
        Release-ComObjects
        throw 'Edge app bundle failed to initialise: {0}' -f $PSItem.Exception.Message
    }

    try {
        $AppBundle.createInstalledApp($AppId)
    } catch {
        Release-ComObjects

        switch -RegEx ($PSItem.Exception.Message) {
            # GOOPDATE_E_APP_UPDATE_DISABLED_BY_POLICY
            '\b0x80040813\b' { throw 'Edge Update reported updates are disabled by policy.' }
            # GOOPDATE_E_APP_UPDATE_DISABLED_BY_POLICY_MANUAL
            '\b0x8004081f\b' { throw 'Edge Update reported updates are disabled by policy (manual).' }
            # GOOPDATE_E_APP_USING_EXTERNAL_UPDATER
            '\b0xA043081D\b' { throw 'Edge Update reported an update is already in-progress.' }
        }

        throw 'Edge app bundle failed to create installed app: {0}' -f $PSItem.Exception.Message
    }

    try {
        # Parameter is index of created app
        $AppUpdate = $AppBundle.appWeb(0)
    } catch {
        Release-ComObjects
        throw 'Failed to retrieve app instance from Edge app bundle: {0}' -f $PSItem.Exception.Message
    }

    try {
        $CurrentVersionWeb = $AppUpdate.currentVersionWeb
        $Result.BeforeUpdate = $CurrentVersionWeb.version
    } catch {
        Release-ComObjects
        throw 'Failed to retrieve current version from Edge app bundle: {0}' -f $PSItem.Exception.Message
    }

    if (!$PSCmdlet.ShouldProcess('Edge', 'Update')) {
        Release-ComObjects
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    $MaxWaitTime = 300 # 5 mins
    $WaitTime = [Diagnostics.Stopwatch]::StartNew()

    do {
        $LastUpdateStateId = $AppUpdate.currentState.stateValue
        if ($UpdateStates.ContainsKey($LastUpdateStateId)) {
            $LastUpdateState = $UpdateStates[$LastUpdateStateId]
        } else {
            $LastUpdateState = 'Unknown'
        }

        $ElapsedSeconds = [Int]($WaitTime.ElapsedMilliseconds / 1000)
        $StatusMsg = 'Update state: {0} (Waited {1} secs / time-out: {2} secs) ...' -f $LastUpdateState, $ElapsedSeconds, $MaxWaitTime
        Write-Progress @WriteProgressParams -Status $StatusMsg

        switch ($LastUpdateStateId) {
            # Initialising
            1 {
                try {
                    $AppBundle.checkForUpdate()
                } catch {
                    Release-ComObjects
                    throw 'Failed to trigger Edge update check: {0}' -f $PSItem.Exception.Message
                }
            }

            # Update available
            4 {
                try {
                    $AppBundle.download()
                } catch {
                    Release-ComObjects
                    throw 'Failed to trigger Edge update download: {0}' -f $PSItem.Exception.Message
                }
            }

            # Ready to install
            11 {
                try {
                    $AppBundle.install()
                } catch {
                    Release-ComObjects
                    throw 'Failed to trigger Edge update install: {0}' -f $PSItem.Exception.Message
                }
            }
        }

        # IDs >= 14 are final states
        if ($LastUpdateStateId -ge 14) {
            $Result.UpdateState = $LastUpdateState
            $Result.UpdateStateId = $LastUpdateStateId
            break
        }

        Start-Sleep -Seconds 1
    } while ($ElapsedSeconds -lt $MaxWaitTime)

    $WaitTime.Stop()
    Write-Progress @WriteProgressParams -Completed

    switch ($Result.UpdateStateId) {
        # Install complete
        14 {
            try {
                $NextVersionWeb = $AppUpdate.nextVersionWeb
                $Result.AfterUpdate = $NextVersionWeb.version
                $Result.Success = $true
            } catch {
                Write-Error -Message ('Failed to retrieve new version from Edge app bundle: {0}' -f $PSItem.Exception.Message)
            }
        }

        # Paused
        15 { Write-Warning -Message 'Edge Update reported the update is paused.' }

        # No update
        16 {
            $Result.AfterUpdate = $Result.BeforeUpdate
            $Result.Success = $true
        }

        # Error
        17 { Write-Error -Message 'Edge Update reported an error occurred.' }

        # Timeout
        -1 {
            $LastUpdateStateMsg = 'Last update state: {1} [ID: {2}]' -f $LastUpdateState, $LastUpdateStateId
            Write-Warning -Message ('Gave-up waiting on Edge update after {0} secs ({1})' -f $MaxWaitTime, $LastUpdateStateMsg)
        }

        # Unknown state ID
        default { Write-Error -Message ('Edge Update reported an unknown state ID: {0}' -f $Result.UpdateStateId) }
    }

    Release-ComObjects
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

# Update Python runtimes
Function Update-Python {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param()

    Function Get-PythonRuntimes {
        [CmdletBinding()]
        [OutputType([String[]])]
        Param()

        $ListArgs = [String[]]@('list', '--format=json')

        Write-Verbose -Message ('Listing Python runtimes: pymanager {0}' -f ($ListArgs -join ' '))
        try {
            $VersionsJsonRaw = & pymanager @ListArgs 2>&1
        } catch {
            $Msg = 'Failed to retrieve Python runtimes: {0}' -f $PSItem.Exception.Message
            Write-Error -Message $Msg
            return [String[]]@($Msg)
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message ('Pymanager returned non-zero exit code listing Python runtimes: {0}' -f $LASTEXITCODE)
            return [String[]]@($VersionsJsonRaw)
        }

        try {
            $VersionsJson = $VersionsJsonRaw | ConvertFrom-Json
        } catch {
            Write-Error -Message ('Failed to parse JSON listing Python runtimes: {0}' -f $PSItem.Exception.Message)
            return [String[]]@($VersionsJsonRaw)
        }

        return [String[]]@($VersionsJson.versions.'display-name')
    }

    if (!(Get-Command -Name 'pymanager' -ErrorAction Ignore)) {
        throw 'Unable to update Python runtimes as pymanager command not found.'
    }

    $Result = [PSCustomObject]@{
        Success      = $false
        BeforeUpdate = [String[]]@()
        AfterUpdate  = [String[]]@()
        Output       = [String[]]@()
        ExitCode     = -1
        WhatIf       = $false
    }
    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdatePython')

    $UpdateArgs = [String[]]@('install', '--update')

    $Result.BeforeUpdate = Get-PythonRuntimes

    $DryrunMsg = ''
    if (!$PSCmdlet.ShouldProcess('Python runtimes', 'Update')) {
        $UpdateArgs += '--dry-run'
        $DryrunMsg = ' (dry-run)'
        $Result.WhatIf = $true
    }

    Write-Verbose -Message ('Updating Python runtimes{0}: pymanager {1}' -f $DryrunMsg, ($UpdateArgs -join ' '))
    try {
        $Result.Output = [String[]]@(& pymanager @UpdateArgs 2>&1)
        $Result.ExitCode = $LASTEXITCODE

        if ($Result.ExitCode -ne 0) {
            Write-Error -Message ('Pymanager returned non-zero exit code updating Python runtimes: {0}' -f $Result.ExitCode)
        } else { $Result.Success = $true }
    } catch {
        $Msg = 'Failed to start Python runtimes update{0}: {1}' -f $DryrunMsg, $PSItem.Exception.Message
        $Result.Output = [String[]]@($Msg)
        Write-Eror -Message $Msg
    }

    $Result.AfterUpdate = Get-PythonRuntimes

    return $Result
}

# Update Scoop, installed apps, and perform clean-up
#
# TODO: Add dependency cooldown support when available
Function Update-Scoop {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Get-Command -Name 'scoop' -ErrorAction Ignore)) {
        throw 'Unable to update Scoop as scoop command not found.'
    }

    $WriteProgressParams = @{ Activity = 'Updating Scoop' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Scoop        = [String[]]@()
        Apps         = @()
        Cleanup      = [String[]]@()
        LastExitCode = -1
        WhatIf       = $false
    }
    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateScoop')

    $UpdateScoopArgs = [String[]]@('update', '--quiet')
    $UpdateAppsArgs = [String[]]@('update', '*', '--quiet')
    $UpdateAppsReportOnlyArgs = [String[]]@('status', '--local')
    $CleanupArgs = [String[]]@('cleanup', '*', '--cache')

    # There's no simple way to disable the output of the download progress bar
    # during Scoop updates. It adds a lot of noise to the captured output, so
    # we filter out relevant lines using a regular expression match.
    $ProgressBarRegex = '\[=*(> *)?\] +[0-9]{1,3}%'

    if ($PSCmdlet.ShouldProcess('Scoop', 'Update')) {
        Write-Progress @WriteProgressParams -Status 'Updating Scoop to latest version' -PercentComplete 1
        Write-Verbose -Message ('Updating Scoop: scoop {0}' -f ($UpdateScoopArgs -join ' '))

        try {
            # Suppress useless verbose output from Scoop
            $VerboseOriginal = $Global:VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            $Result.Scoop = [String[]]@(& scoop @UpdateScoopArgs 6>&1)
        } catch {
            $LASTEXITCODE = -1
            $Msg = 'Failed to start Scoop update: {0}' -f $PSItem.Exception.Message
            $Result.Scoop = [String[]]@($Msg)
            Write-Eror -Message $Msg
        } finally {
            $VerbosePreference = $VerboseOriginal
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message ('Scoop update returned non-zero exit code: {0}' -f $LASTEXITCODE)
            Write-Progress @WriteProgressParams -Completed
            return $Result
        }
    }

    $ReportOnlyMsg = ''
    if (!$PSCmdlet.ShouldProcess('Scoop apps', 'Update')) {
        $UpdateAppsArgs = $UpdateAppsReportOnlyArgs
        $ReportOnlyMsg = ' (report only)'
        $Result.WhatIf = $true
    }

    Write-Progress @WriteProgressParams -Status 'Updating apps' -PercentComplete 20
    Write-Verbose -Message ('Updating Scoop apps{0}: scoop {1}' -f $ReportOnlyMsg, ($UpdateAppsArgs -join ' '))

    try {
        # Suppress useless verbose output from Scoop
        $VerboseOriginal = $Global:VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        $Result.Apps = @(& scoop @UpdateAppsArgs 6>&1 | Where-Object { $_ -notmatch $ProgressBarRegex })
    } catch {
        $LASTEXITCODE = -1
        $Msg = 'Failed to start Scoop apps update{0}: {1}' -f $ReportOnlyMsg, $PSItem.Exception.Message
        $Result.Apps = [String[]]@($Msg)
        Write-Eror -Message $Msg
    } finally {
        $VerbosePreference = $VerboseOriginal
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message ('Scoop apps update returned non-zero exit code: {0}' -f $LASTEXITCODE)
        Write-Progress @WriteProgressParams -Completed
        return $Result
    }

    if ($PSCmdlet.ShouldProcess('Scoop outdated data', 'Remove')) {
        Write-Progress @WriteProgressParams -Status 'Cleaning-up outdated data' -PercentComplete 80
        Write-Verbose -Message ('Cleaning-up outdated Scoop data: scoop {0}' -f ($CleanupArgs -join ' '))

        try {
            # Suppress useless verbose output from Scoop
            $VerboseOriginal = $Global:VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            $Result.Cleanup = [String[]]@(& scoop @CleanupArgs 6>&1)
        } catch {
            $LASTEXITCODE = -1
            $Msg = 'Failed to start Scoop clean-up: {0}' -f $PSItem.Exception.Message
            $Result.Cleanup = [String[]]@($Msg)
            Write-Eror -Message $Msg
        } finally {
            $VerbosePreference = $VerboseOriginal
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message ('Scoop clean-up returned non-zero exit code: {0}' -f $LASTEXITCODE)
            Write-Progress @WriteProgressParams -Completed
            return $Result
        }
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

# Update Microsoft WinGet
#
# TODO: Add dependency cooldown support when available
Function Update-WinGet {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param()

    if (!(Get-Command -Name 'winget' -ErrorAction Ignore)) {
        throw 'Unable to update WinGet as winget command not found.'
    }

    try {
        Import-Module -Name 'Microsoft.WinGet.Client' -ErrorAction Stop -Verbose:$false
    } catch {
        throw 'Unable to update WinGet as Microsoft.WinGet.Client module not available.'
    }

    $Result = [PSCustomObject]@{
        # Set to false if any updates fail
        Success   = $true
        Available = @()
        Results   = @()
        WhatIf    = $false
    }
    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateWinGet')

    Write-Verbose -Message 'Retrieving all WinGet packages ...'
    try {
        $Packages = Get-WinGetPackage
    } catch {
        throw 'Failed to enumerate installed WinGet packages: {0}' -f $PSItem.Exception.Message
    }

    $Result.Available = @($Packages | Where-Object IsUpdateAvailable)
    Write-Verbose -Message ('Found {0} updates across {1} installed packages.' -f $Result.Available.Count, $Packages.Count)

    # `Update-WinGetPackage` doesn't properly support `-WhatIf`; it will
    # install package updates even if `-WhatIf` is set.
    if (!$PSCmdlet.ShouldProcess('WinGet apps', 'Update')) {
        $Result.WhatIf = $true
        return $Result
    }

    $InstallResults = [Collections.Generic.List[Object]]::new()
    foreach ($Update in $Result.Available) {
        try {
            $InstallResult = Update-WinGetPackage -Id $Update.Id -Verbose:$false
            $InstallResults.Add($InstallResult)
        } catch {
            Write-Error -Message ('Failed to update package {0}: {1}' -f $Update.Name, $PSItem.Exception.Message)
            $Result.Success = $false
        }
    }

    if ($Result.Success) {
        $Failed = @($InstallResults | Where-Object Status -NE 'OK')
        if ($Failed) { $Result.Success = $false }
    }

    $Result.Results = $InstallResults.ToArray()
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
