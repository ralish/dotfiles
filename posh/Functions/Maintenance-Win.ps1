$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Maintenance (Windows)'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

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

        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    Function Clear-ComObjects {
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
        BeforeUpdate  = ''
        AfterUpdate   = ''
        UpdateState   = ''
        UpdateStateId = -1
        WhatIf        = $false
    }

    switch ($UpdateChannel) {
        'Stable' { $AppId = '{8A69D345-D564-463c-AFF1-A69D9E530F96}' }
        'Beta' { $AppId = '{8237E44A-0054-442C-B6B6-EA0509993955}' }
        'Dev' { $AppId = '{401C381F-E0DE-4B85-8BD8-3F3F14FBDA57}' }
        'Canary' { $AppId = '{4EA16AC7-FD5A-47C3-875B-DBF4A2008C20}' }
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

    # So we don't free existing COM objects in the (extremely unlikely) case
    # that they're using the same variable names in a parent scope.
    $GoogleUpdate = $null
    $AppBundle = $null
    $AppUpdate = $null
    $CurrentVersionWeb = $null
    $NextVersionWeb = $null

    # Errors returned from COM objects are surfaced by the .NET runtime as
    # a generic `RuntimeException` (`0x80131501` / `COR_E_SYSTEM`), which
    # requires inspection of the exception message to determine the failure.

    try {
        $GoogleUpdate = New-Object -ComObject $ComObjectName
    } catch {
        Clear-ComObjects

        $Exc = $PSItem
        switch -RegEx ($Exc.Exception.Message) {
            # REGDB_E_CLASSNOTREG
            '\b0x80040154\b' { $ErrMsg = 'Unable to update Chrome as Google Update is not available.' }
            default { $ErrMsg = "Google Update COM object failed to activate: $($Exc.Exception.Message)" }
        }

        $ErrExc = [Exception]::new($ErrMsg, $Exc.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $AppBundle = $GoogleUpdate.createAppBundleWeb()
    } catch {
        Clear-ComObjects

        $ErrMsg = "Google Update failed to create Chrome app bundle: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $AppBundle.initialize()
    } catch {
        Clear-ComObjects

        $ErrMsg = "Chrome app bundle failed to initialise: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $AppBundle.createInstalledApp($AppId)
    } catch {
        Clear-ComObjects

        $Exc = $PSItem
        switch -RegEx ($Exc.Exception.Message) {
            # GOOPDATE_E_APP_UPDATE_DISABLED_BY_POLICY
            '\b0x80040813\b' { $ErrMsg = 'Google Update reported updates are disabled by policy.' }
            # GOOPDATE_E_APP_UPDATE_DISABLED_BY_POLICY_MANUAL
            '\b0x8004081f\b' { $ErrMsg = 'Google Update reported updates are disabled by policy (manual).' }
            # GOOPDATE_E_APP_USING_EXTERNAL_UPDATER
            '\b0xA043081D\b' { $ErrMsg = 'Google Update reported an update is already in-progress.' }
            default { $ErrMsg = "Chrome app bundle failed to create installed app: $($Exc.Exception.Message)" }
        }

        $ErrExc = [Exception]::new($ErrMsg, $Exc.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        # Parameter is index of created app
        $AppUpdate = $AppBundle.appWeb(0)
    } catch {
        Clear-ComObjects

        $ErrMsg = "Failed to retrieve app instance from Chrome app bundle: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $CurrentVersionWeb = $AppUpdate.currentVersionWeb
        $Result.BeforeUpdate = $CurrentVersionWeb.version
    } catch {
        Clear-ComObjects

        $ErrMsg = "Failed to retrieve current version from Chrome app bundle: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (!$PSCmdlet.ShouldProcess('Chrome', 'Update')) {
        Clear-ComObjects
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
        $StatusMsg = "Update state: ${LastUpdateState} (Waited ${ElapsedSeconds} secs / time-out: ${MaxWaitTime} secs) ..."
        Write-Progress @WriteProgressParams -Status $StatusMsg

        switch ($LastUpdateStateId) {
            # Initialising
            1 {
                try {
                    $AppBundle.checkForUpdate()
                } catch {
                    Clear-ComObjects

                    $ErrMsg = "Failed to trigger Chrome update check: $($PSItem.Exception.Message)"
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }

            # Update available
            4 {
                try {
                    $AppBundle.download()
                } catch {
                    Clear-ComObjects

                    $ErrMsg = "Failed to trigger Chrome update download: $($PSItem.Exception.Message)"
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }

            # Ready to install
            11 {
                try {
                    $AppBundle.install()
                } catch {
                    Clear-ComObjects

                    $ErrMsg = "Failed to trigger Chrome update install: $($PSItem.Exception.Message)"
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
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
                $ErrMsg = "Failed to retrieve new version from Chrome app bundle: $($PSItem.Exception.Message)"
                $ErrExc = [Exception]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
                $PSCmdlet.WriteError($ErrRec)
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
        17 {
            $ErrMsg = 'Google Update reported an error occurred.'
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
            $PSCmdlet.WriteError($ErrRec)
        }

        # Timeout
        -1 {
            $LastUpdateStateMsg = "Last update state: ${LastUpdateState} [ID: ${LastUpdateStateId}]"
            Write-Warning -Message "Gave-up waiting on Chrome update after ${MaxWaitTime} secs (${LastUpdateStateMsg})"
        }

        # Unknown state ID
        default {
            $ErrMsg = "Google Update reported an unknown state ID: $($Result.UpdateStateId)"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
            $PSCmdlet.WriteError($ErrRec)
        }
    }

    Clear-ComObjects
    return $Result
}

# Update Microsoft Edge
Function Update-Edge {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateSet('Stable', 'Beta', 'Dev', 'Canary')]
        [String]$UpdateChannel = 'Stable',

        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    Function Clear-ComObjects {
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
        BeforeUpdate  = ''
        AfterUpdate   = ''
        UpdateState   = ''
        UpdateStateId = -1
        WhatIf        = $false
    }

    switch ($UpdateChannel) {
        'Stable' { $AppId = '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' }
        'Beta' { $AppId = '{2CD8A007-E189-409D-A2C8-9AF4EF3C72AA}' }
        'Dev' { $AppId = '{0D50BFEC-CD6A-4F9A-964C-C7416E3ACB10}' }
        'Canary' { $AppId = '{65C35B14-6C1D-4122-AC46-7148CC9D6497}' }
    }

    $ComObjectName = 'MicrosoftEdgeUpdate.Update3WebMachine'

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

    # So we don't free existing COM objects in the (extremely unlikely) case
    # that they're using the same variable names in a parent scope.
    $EdgeUpdate = $null
    $AppBundle = $null
    $AppUpdate = $null
    $CurrentVersionWeb = $null
    $NextVersionWeb = $null

    # Errors returned from COM objects are surfaced by the .NET runtime as
    # a generic `RuntimeException` (`0x80131501` / `COR_E_SYSTEM`), which
    # requires inspection of the exception message to determine the failure.

    try {
        $EdgeUpdate = New-Object -ComObject $ComObjectName
    } catch {
        Clear-ComObjects

        $Exc = $PSItem
        switch -RegEx ($Exc.Exception.Message) {
            # REGDB_E_CLASSNOTREG
            '\b0x80040154\b' { $ErrMsg = 'Unable to update Edge as Edge Update is not available.' }
            default { $ErrMsg = "Edge Update COM object failed to activate: $($Exc.Exception.Message)" }
        }

        $ErrExc = [Exception]::new($ErrMsg, $Exc.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $AppBundle = $EdgeUpdate.createAppBundleWeb()
    } catch {
        Clear-ComObjects

        $ErrMsg = "Edge Update failed to create Edge app bundle: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $AppBundle.initialize()
    } catch {
        Clear-ComObjects

        $ErrMsg = "Edge app bundle failed to initialise: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $AppBundle.createInstalledApp($AppId)
    } catch {
        Clear-ComObjects

        $Exc = $PSItem
        switch -RegEx ($Exc.Exception.Message) {
            '\b0x80040813\b' { $ErrMsg = 'Edge Update reported updates are disabled by policy.' }
            '\b0x8004081f\b' { $ErrMsg = 'Edge Update reported updates are disabled by policy (manual).' }
            '\b0xA043081D\b' { $ErrMsg = 'Edge Update reported an update is already in-progress.' }
            default { $ErrMsg = "Edge app bundle failed to create installed app: $($Exc.Exception.Message)" }
        }

        $ErrExc = [Exception]::new($ErrMsg, $Exc.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        # Parameter is index of created app
        $AppUpdate = $AppBundle.appWeb(0)
    } catch {
        Clear-ComObjects

        $ErrMsg = "Failed to retrieve app instance from Edge app bundle: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $CurrentVersionWeb = $AppUpdate.currentVersionWeb
        $Result.BeforeUpdate = $CurrentVersionWeb.version
    } catch {
        Clear-ComObjects

        $ErrMsg = "Failed to retrieve current version from Edge app bundle: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (!$PSCmdlet.ShouldProcess('Edge', 'Update')) {
        Clear-ComObjects
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
        $StatusMsg = "Update state: ${LastUpdateState} (Waited ${ElapsedSeconds} secs / time-out: ${MaxWaitTime} secs) ..."
        Write-Progress @WriteProgressParams -Status $StatusMsg

        switch ($LastUpdateStateId) {
            # Initialising
            1 {
                try {
                    $AppBundle.checkForUpdate()
                } catch {
                    Clear-ComObjects

                    $ErrMsg = "Failed to trigger Edge update check: $($PSItem.Exception.Message)"
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }

            # Update available
            4 {
                try {
                    $AppBundle.download()
                } catch {
                    Clear-ComObjects

                    $ErrMsg = "Failed to trigger Edge update download: $($PSItem.Exception.Message)"
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }

            # Ready to install
            11 {
                try {
                    $AppBundle.install()
                } catch {
                    Clear-ComObjects

                    $ErrMsg = "Failed to trigger Edge update install: $($PSItem.Exception.Message)"
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
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
                $ErrMsg = "Failed to retrieve new version from Edge app bundle: $($PSItem.Exception.Message)"
                $ErrExc = [Exception]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
                $PSCmdlet.WriteError($ErrRec)
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
        17 {
            $ErrMsg = 'Edge Update reported an error occurred.'
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
            $PSCmdlet.WriteError($ErrRec)
        }

        # Timeout
        -1 {
            $LastUpdateStateMsg = "Last update state: ${LastUpdateState} [ID: ${LastUpdateStateId}]"
            Write-Warning -Message "Gave-up waiting on Edge update after ${MaxWaitTime} secs (${LastUpdateStateMsg})"
        }

        # Unknown state ID
        default {
            $ErrMsg = "Edge Update reported an unknown state ID: $($Result.UpdateStateId)"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ComApiFailed', $ErrCat, $null)
            $PSCmdlet.WriteError($ErrRec)
        }
    }

    Clear-ComObjects
    return $Result
}

# Update Microsoft Store apps
Function Update-MicrosoftStore {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param()

    if (!(Test-IsAdministrator)) {
        $ErrMsg = 'You must have administrator privileges to update Microsoft Store apps.'
        $ErrExc = [UnauthorizedAccessException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::PermissionDenied
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NoAdminPrivileges', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
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
        $Session = New-CimSession -ErrorAction 'Stop' -Verbose:$false
    } catch {
        $ErrMsg = "Error creating new WMI session: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'WmiApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $Instance = Get-CimInstance -Namespace $Namespace -ClassName $ClassName -ErrorAction 'Stop'
    } catch {
        $ErrMsg = "Unable to update Microsoft Store apps as ${ClassName} WMI class is not available: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'WmiApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    # Modern PowerShell releases throw an exception on trying to instantiate a
    # non-existing class but older releases just return `null`. This includes
    # Windows PowerShell 5.1, which is still the latest inbox version.
    if (!$Instance) {
        $ErrMsg = "Unable to update Microsoft Store apps as ${ClassName} WMI class is not available."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'WmiApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (!$PSCmdlet.ShouldProcess('Microsoft Store apps', 'Update')) {
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    try {
        $UpdateScan = $Session.InvokeMethod($Namespace, $Instance, $MethodName, $null)
    } catch {
        $ErrMsg = "Error invoking ${MethodName} method of ${ClassName} WMI class: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'WmiApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result.ReturnValue = $UpdateScan.ReturnValue.Value
    if ($Result.ReturnValue -eq 0) {
        $Result.Success = $true
    } else {
        $ErrMsg = "Update of Microsoft Store apps returned: $($Result.ReturnValue)"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'WmiApiFailed', $ErrCat, $null)
        $PSCmdlet.WriteError($ErrRec)
    }

    return $Result
}

# Update Microsoft Office (Click-to-Run only)
Function Update-Office {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    $WriteProgressParams = @{ Activity = 'Updating Office' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Success        = $false
        BeforeUpdate   = ''
        AfterUpdate    = ''
        ScenarioResult = ''
        WhatIf         = $false
    }

    $OfficeC2RClient = Join-Path -Path ${Env:ProgramFiles} -ChildPath 'Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe'
    if (!(Test-Path -LiteralPath $OfficeC2RClient -PathType 'Leaf')) {
        $ErrMsg = "Unable to update Office as Click-to-Run client not found: ${OfficeC2RClient}"
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, $OfficeC2RClient)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $C2RRegPath = 'HKLM:\Software\Microsoft\Office\ClickToRun'
        $C2RRegKey = Get-Item -LiteralPath $C2RRegPath -ErrorAction 'Stop'
    } catch {
        $ErrMsg = "Error retrieving Office Click-to-Run registry key: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegistryKeyNotFound', $ErrCat, $C2RRegPath)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $ConfigRegPath = Join-Path -Path $C2RRegPath -ChildPath 'Configuration'
        $ConfigRegKey = Get-Item -LiteralPath $ConfigRegPath -ErrorAction 'Stop'
    } catch {
        $ErrMsg = "Error retrieving Office Click-to-Run configuration registry key: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegistryKeyNotFound', $ErrCat, $ConfigRegPath)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Version = $null
    $RawVersion = $ConfigRegKey.GetValue('VersionToReport')
    if (![Version]::TryParse($RawVersion, [Ref]$Version)) {
        Write-Warning -Message "Failed to parse pre-update Office version: ${RawVersion}"
    }

    $Result.BeforeUpdate = $Version

    if (!$PSCmdlet.ShouldProcess('Office', 'Update')) {
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    try {
        Write-Progress @WriteProgressParams
        $UpdateArgs = '/update', 'user', 'updatepromptuser=True'
        $UpdateCmd = "${OfficeC2RClient} $($UpdateArgs -join ' ')"
        Start-Process -FilePath $OfficeC2RClient -ArgumentList $UpdateArgs -ErrorAction 'Stop'
    } catch {
        $ErrMsg = "Failed to start Office Click-To-Run Client: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidOperation
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $MaxWaitTime = 900 # 15 mins
    $WaitTime = [Diagnostics.Stopwatch]::StartNew()

    do {
        Start-Sleep -Seconds 5
        $ElapsedSeconds = [Int]($WaitTime.ElapsedMilliseconds / 1000)

        $ExecutingScenario = $C2RRegKey.GetValue('ExecutingScenario')
        if (!$ExecutingScenario) {
            $LastScenario = $C2RRegKey.GetValue('LastScenario')
            $LastScenarioResult = $C2RRegKey.GetValue('LastScenarioResult')
            break
        }

        $StatusMsg = "Executing Scenario: ${ExecutingScenario} (Waited ${ElapsedSeconds} secs / time-out: ${MaxWaitTime} secs) ..."
        Write-Progress @WriteProgressParams -Status $StatusMsg

        $TasksRegPath = Join-Path -Path $C2RRegPath -ChildPath "Scenario\${ExecutingScenario}\TasksState"
        $TasksRegKey = Get-Item -LiteralPath $TasksRegPath
        foreach ($Task in $TasksRegKey.GetValueNames()) {
            $TaskName = $Task.Split(':')[0]
            $TaskStatus = $TasksRegKey.GetValue($Task)

            switch ($TaskStatus) {
                'TASKSTATE_CANCELLED' { Write-Warning -Message "Office update task cancelled in ${ExecutingScenario} scenario: ${TaskName}" }
                'TASKSTATE_FAILED' { Write-Warning -Message "Office update task failed in ${ExecutingScenario} scenario: ${TaskName}" }
            }
        }
    } while ($ElapsedSeconds -lt $MaxWaitTime)

    $WaitTime.Stop()
    Write-Progress @WriteProgressParams -Completed

    if ($ElapsedSeconds -ge $MaxWaitTime) {
        $ErrMsg = "Office update exceeded maximum wait time of ${MaxWaitTime} seconds."
        $ErrExc = [TimeoutException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::OperationTimeout
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandTimeout', $ErrCat, $UpdateCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    Write-Verbose -Message "Office update finished ${LastScenario} scenario with result: ${LastScenarioResult}"
    $Result.ScenarioResult = $LastScenarioResult
    if ($Result.ScenarioResult -eq 'Success') {
        $Result.Success = $true
    }

    $Version = $null
    $RawVersion = $ConfigRegKey.GetValue('VersionToReport')
    if (![Version]::TryParse($RawVersion, [Ref]$Version)) {
        Write-Warning -Message "Failed to parse post-update Office version: ${RawVersion}"
    }

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

        $ListArgs = 'list', '--format=json'
        $ListCmd = "pymanager $($ListArgs -join ' ')"

        Write-Verbose -Message "Listing Python runtimes: ${ListCmd}"
        $VersionsJsonRaw = & pymanager @ListArgs 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Pymanager exited with non-zero exit code listing Python runtimes: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $ListCmd)
            $PSCmdlet.WriteError($ErrRec)
            return [String[]]@($VersionsJsonRaw)
        }

        try {
            $VersionsJson = $VersionsJsonRaw | ConvertFrom-Json -ErrorAction 'Stop'
        } catch {
            $ErrMsg = "Failed to parse JSON listing Python runtimes: $($PSItem.Exception.Message)"
            $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'JsonParseFailed', $ErrCat, $VersionsJsonRaw)
            $PSCmdlet.WriteError($ErrRec)
            return [String[]]@($VersionsJsonRaw)
        }

        return [String[]]@($VersionsJson.versions.'display-name')
    }

    if (!(Get-Command -Name 'pymanager' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update Python runtimes as pymanager command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'pymanager')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result = [PSCustomObject]@{
        Success      = $false
        BeforeUpdate = ''
        AfterUpdate  = ''
        Output       = [String[]]@()
        ExitCode     = -1
        WhatIf       = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdatePython')

    $UpdateArgs = 'install', '--update'
    $UpdateCmd = "pymanager $($UpdateArgs -join ' ')"

    $Result.BeforeUpdate = Get-PythonRuntimes

    $DryrunMsg = ''
    if (!$PSCmdlet.ShouldProcess('Python runtimes', 'Update')) {
        $DryrunMsg = ' (dry-run)'
        $UpdateArgs += '--dry-run'
        $UpdateCmd += ' --dry-run'
        $Result.WhatIf = $true
    }

    Write-Verbose -Message "Updating Python runtimes${DryrunMsg}: ${UpdateCmd}"
    $Result.Output = [String[]]@(& pymanager @UpdateArgs 2>&1)
    $Result.ExitCode = $LASTEXITCODE

    if ($Result.ExitCode -eq 0) {
        $Result.Success = $true
    } else {
        $ErrMsg = "Pymanager exited with non-zero exit code updating Python runtimes: $($Result.ExitCode)"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $null)
        $PSCmdlet.WriteError($ErrRec)
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
        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    if (!(Get-Command -Name 'scoop' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update Scoop as scoop command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSScriptNotFound', $ErrCat, 'scoop')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $WriteProgressParams = @{ Activity = 'Updating Scoop' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Scoop        = [String[]]@()
        Apps         = [String[]]@()
        Cleanup      = [String[]]@()
        LastExitCode = -1
        WhatIf       = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateScoop')

    $UpdateScoopArgs = 'update', '--quiet'
    $UpdateScoopCmd = "scoop $($UpdateScoopArgs -join ' ')"

    $UpdateAppsArgs = 'update', '*', '--quiet'
    $UpdateAppsCmd = "scoop $($UpdateAppsArgs -join ' ')"

    $UpdateAppsReportOnlyArgs = 'status', '--local'
    $UpdateAppsReportOnlyCmd = "scoop $($UpdateAppsReportOnlyArgs -join ' ')"

    $CleanupArgs = 'cleanup', '*', '--cache'
    $CleanupCmd = "scoop $($CleanupArgs -join ' ')"

    # There's no simple way to disable the output of the download progress bar
    # during Scoop updates. It adds a lot of noise to the captured output, so
    # we filter out relevant lines using a regular expression.
    $ProgressBarRegex = '\[=*(> *)?\] +[0-9]{1,3}%'

    if ($PSCmdlet.ShouldProcess('Scoop', 'Update')) {
        Write-Progress @WriteProgressParams -Status 'Updating Scoop to latest version' -PercentComplete 1
        Write-Verbose -Message "Updating Scoop: ${UpdateScoopCmd}"

        try {
            # Suppress useless verbose output from Scoop
            $VerboseOriginal = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'

            $Result.Scoop = [String[]]@(& scoop @UpdateScoopArgs 6>&1)
        } catch {
            $LASTEXITCODE = -1
        } finally {
            $VerbosePreference = $VerboseOriginal
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Progress @WriteProgressParams -Completed

            $ErrMsg = "Scoop update exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSScriptFailed', $ErrCat, $UpdateScoopCmd)
            $PSCmdlet.WriteError($ErrRec)
            return $Result
        }
    }

    $ReportOnlyMsg = ''
    if (!$PSCmdlet.ShouldProcess('Scoop apps', 'Update')) {
        $ReportOnlyMsg = ' (report only)'
        $UpdateAppsArgs = $UpdateAppsReportOnlyArgs
        $UpdateAppsCmd = $UpdateAppsReportOnlyCmd
        $Result.WhatIf = $true
    }

    Write-Progress @WriteProgressParams -Status 'Updating apps' -PercentComplete 20
    Write-Verbose -Message "Updating Scoop apps${ReportOnlyMsg}: ${UpdateAppsCmd}"

    try {
        # Suppress useless verbose output from Scoop
        $VerboseOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'

        # Scoop may emit a "What if" output for updating formatting data. This
        # action is harmless so temporarily disable `WhatIf` mode.
        $WhatIfOriginal = $WhatIfPreference
        $WhatIfPreference = $false

        $Result.Apps = [String[]]@(& scoop @UpdateAppsArgs 6>&1 | Where-Object { $PSItem -notmatch $ProgressBarRegex })
    } catch {
        $LASTEXITCODE = -1
    } finally {
        $VerbosePreference = $VerboseOriginal
        $WhatIfPreference = $WhatIfOriginal
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Progress @WriteProgressParams -Completed

        $ErrMsg = "Scoop apps update exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSScriptFailed', $ErrCat, $UpdateAppsCmd)
        $PSCmdlet.WriteError($ErrRec)
        return $Result
    }

    if ($PSCmdlet.ShouldProcess('Scoop outdated data', 'Remove')) {
        Write-Progress @WriteProgressParams -Status 'Cleaning-up outdated data' -PercentComplete 80
        Write-Verbose -Message "Cleaning-up outdated Scoop data: ${CleanupCmd}"

        try {
            # Suppress useless verbose output from Scoop
            $VerboseOriginal = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'

            $Result.Cleanup = [String[]]@(& scoop @CleanupArgs 6>&1)
        } catch {
            $LASTEXITCODE = -1
        } finally {
            $VerbosePreference = $VerboseOriginal
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Progress @WriteProgressParams -Completed

            $ErrMsg = "Scoop clean-up exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSScriptFailed', $ErrCat, $CleanupCmd)
            $PSCmdlet.WriteError($ErrRec)
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
        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    if (!(Test-IsAdministrator)) {
        $ErrMsg = 'You must have administrator privileges to update Visual Studio.'
        $ErrExc = [UnauthorizedAccessException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::PermissionDenied
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NoAdminPrivileges', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        Import-Module -Name 'VSSetup' -ErrorAction 'Stop' -Verbose:$false
    } catch {
        $ErrMsg = 'Unable to update Visual Studio as VSSetup module not available.'
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotFound', $ErrCat, 'VSSetup')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $WriteProgressParams = @{ Activity = 'Updating Visual Studio' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Success      = $true
        BeforeUpdate = @() # `Microsoft.VisualStudio.Setup.Instance[]`
        AfterUpdate  = @() # `Microsoft.VisualStudio.Setup.Instance[]`
        Errors       = [String[]]@()
        WhatIf       = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateVisualStudio')

    # Visual Studio Installer is always(?) installed under the 32-bit path
    if ([Environment]::Is64BitOperatingSystem) {
        $ProgramFiles = ${Env:ProgramFiles(x86)}
    } else {
        $ProgramFiles = ${Env:ProgramFiles}
    }

    $VsInstallerPath = Join-Path -Path $ProgramFiles -ChildPath 'Microsoft Visual Studio\Installer\vs_installer.exe'
    if (!(Test-Path -LiteralPath $VsInstallerPath -PathType 'Leaf')) {
        $ErrMsg = "Unable to update Visual Studio as VS Installer not found: ${VsInstallerPath}"
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, $VsInstallerPath)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $VsSetupInstances = @(Get-VSSetupInstance | Sort-Object -Property 'InstallationVersion')
    if ($VsSetupInstances.Count -eq 0) {
        $ErrMsg = 'Get-VSSetupInstance returned no Visual Studio installations.'
        $ErrExc = [InvalidOperationException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'ApplicationNotFound', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
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
    for ($i = 0; $i -lt $VsSetupInstances.Count; $i++) {
        $VsSetupInstance = $VsSetupInstances[$i]
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
        # Whatever it does seriously confuses PowerShell and/or `PSReadLine`,
        # which seemingly loses track of the console state; subsequent output
        # will often overlap earlier debug output from the installer.
        #
        # A workaround is to launch the installer from a separate console. We
        # do that by launching `cmd` and then the installer within it. `cmd`
        # will return the exit code of the installer when it itself exits.
        #
        # Also, the argument quoting for `cmd` looks weird and wrong. It's not;
        # `cmd` itself is weird and wrong. See its documentation for specifics.
        Write-Progress @WriteProgressParams -Status "Updating ${VsDisplayName}" -PercentComplete ($i / $VsSetupInstances.Count * 100)
        $VsInstallerArgs = 'update --installPath "{0}" --passive --norestart' -f $VsSetupInstance.InstallationPath
        $CmdArgs = '/D /C ""{0}" {1}"' -f $VsInstallerPath, $VsInstallerArgs
        $UpdateCmd = "cmd $($CmdArgs -join ' ')"

        try {
            $VsInstaller = Start-Process -FilePath ${Env:ComSpec} -ArgumentList $CmdArgs -PassThru -Wait -ErrorAction 'Stop'
        } catch {
            $Result.Success = $false

            $ErrMsg = "Failed to start Visual Studio Installer: $($PSItem.Exception.Message)"
            $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidOperation
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateCmd)
            $PSCmdlet.WriteError($ErrRec)

            $VsUpdateErrors.Add($ErrMsg)
            break
        }

        # If the mutex existed at any point while running this loop the exit
        # code we have from the original installer is not meaningful for the
        # update of Visual Studio itself. We'll output a warning later on.
        $VsInstallerUpdated = $false
        $VsInstallerMutexCreated = $false

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
            Write-Warning -Message "${VsDisplayName} update exit code may be unreliable."
        }

        switch ($VsInstaller.ExitCode) {
            0 { } # Success

            3010 {
                Write-Warning -Message "${VsDisplayName} successfully updated but requires a reboot."
            }

            default {
                $Result.Success = $false

                $ErrMsg = "Update of ${VsDisplayName} exited with non-zero exit code: $($VsInstaller.ExitCode)"
                $ErrExc = [Exception]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateCmd)
                $PSCmdlet.WriteError($ErrRec)

                $VsUpdateErrors.Add($ErrMsg)
            }
        }
    }

    $Result.Errors = [String[]]@($VsUpdateErrors.ToArray())

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

        [Parameter(ParameterSetName = 'Include', Mandatory)]
        [ValidateSet('Critical Updates', 'Definition Updates', 'Driver Sets', 'Drivers', 'Feature Packs', 'Security Updates', 'Service Packs', 'Tools', 'Update Rollups', 'Updates', 'Upgrades')]
        [String[]]$IncludeCategories
    )

    if (!(Test-IsAdministrator)) {
        $ErrMsg = 'You must have administrator privileges to update Windows.'
        $ErrExc = [UnauthorizedAccessException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::PermissionDenied
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NoAdminPrivileges', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        Import-Module -Name 'PSWindowsUpdate' -ErrorAction 'Stop' -Verbose:$false
    } catch {
        $ErrMsg = 'Unable to update Windows as PSWindowsUpdate module not available.'
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotFound', $ErrCat, 'PSWindowsUpdate')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result = [PSCustomObject]@{
        # Set to false if any updates fail to download/install
        Success = $true
        Summary = ''
        Updates = @() # `__ComObject[]`
        WhatIf  = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateWindows')

    switch ($PSCmdlet.ParameterSetName) {
        'Exclude' { $UpdateParams = @{ 'NotCategory' = $ExcludeCategories } }
        'Include' { $UpdateParams = @{ 'Category' = $IncludeCategories } }
    }

    # `Get-WindowsUpdate` doesn't correctly support `-WhatIf`; it will install
    # Windows updates when `-Install` is provided even if `-WhatIf` is set.
    if ($PSCmdlet.ShouldProcess('Windows', 'Update')) {
        $UpdateParams.Add('Install', $true)
        $UpdateParams.Add('AcceptAll', $true)
        $UpdateParams.Add('IgnoreReboot', $true)
    } else {
        $Result.WhatIf = $true
    }

    # HACK: `PSWindowsUpdate` returns three instances of each update result.
    # Keep only unique KBs on the grounds the installation of a given update
    # will only be attempted once for a given invocation.
    $Result.Updates = Get-WindowsUpdate @UpdateParams | Sort-Object -Property 'KB' -Unique

    if ($Result.Updates.Count -eq 0) {
        $Result.Summary = 'No updates found'
    } elseif ($Result.WhatIf) {
        $Result.Summary = "Found $($Result.Updates.Count) updates (scan only)"
    } else {
        # STATUS        DESC
        # A------       Accepted
        # R------       Rejected
        # -D-----       Downloaded
        # -F-----       Download failed
        # --I----       Installed
        # --F----       Install failed
        # --R----       Reboot required
        # ---M---       Mandatory
        # ----H--       Hidden
        # -----U-       Uninstallable
        # ------B       Beta
        $Failed = 0
        $Installed = 0
        $NeedReboot = $false

        foreach ($Update in $Result.Updates) {
            if ($Update.Status -match '^.(F.|.F)....$') { $Failed++; continue }
            if ($Update.Status -match '^..I....$') { $Installed++; continue }
            if ($Update.Status -match '^..R....$') { $Installed++; $NeedReboot = $true }
        }

        if ($Failed -gt 0) {
            $Result.Success = $false
        }

        $RebootMsg = ''
        if ($NeedReboot) {
            $RebootMsg = ' (reboot required)'
        }

        $Result.Summary = "${Installed} installed${RebootMsg}, ${Failed} failed, $($Result.Updates.Count) total"
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

    if (!(Get-Command -Name 'winget' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update WinGet packages as winget command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'winget')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        Import-Module -Name 'Microsoft.WinGet.Client' -ErrorAction 'Stop' -Verbose:$false
    } catch {
        $ErrMsg = 'Unable to update WinGet as Microsoft.WinGet.Client module not available.'
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotFound', $ErrCat, 'Microsoft.WinGet.Client')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result = [PSCustomObject]@{
        # Set to false if any updates fail
        Success   = $true
        Available = @() # `Microsoft.WinGet.Client.Engine.PSObjects.PSCatalogPackage[]`
        Results   = @() # `Microsoft.WinGet.Client.Engine.PSObjects.PSInstallResult[]`
        WhatIf    = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateWinGet')

    try {
        Write-Verbose -Message 'Retrieving all WinGet packages ...'
        $Packages = Get-WinGetPackage -ErrorAction 'Stop'
    } catch {
        $ErrMsg = "Failed to enumerate installed WinGet packages: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSCommandFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result.Available = @($Packages | Where-Object IsUpdateAvailable)
    Write-Verbose -Message "Found $($Result.Available.Count) updates across $($Packages.Count) installed packages."

    # `Update-WinGetPackage` doesn't correctly support `-WhatIf`; it will
    # install package updates even if `-WhatIf` is set.
    if (!$PSCmdlet.ShouldProcess('WinGet apps', 'Update')) {
        $Result.WhatIf = $true
        return $Result
    }

    $InstallResults = [Collections.Generic.List[PSObject]]::new()
    foreach ($Update in $Result.Available) {
        try {
            $InstallResult = Update-WinGetPackage -Id $Update.Id -ErrorAction 'Stop' -Verbose:$false
            $InstallResults.Add($InstallResult)
        } catch {
            $Result.Success = $false

            $ErrMsg = "Failed to update package $($Update.Name): $($PSItem.Exception.Message)"
            $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSCommandFailed', $ErrCat, $null)
            $PSCmdlet.WriteError($ErrRec)
        }
    }

    if ($Result.Success) {
        $Failed = @($InstallResults | Where-Object Status -NE 'OK')
        if ($Failed) {
            $Result.Success = $false
        }
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

        $StatusArgs = @('--status')
        $StatusCmd = "wsl $($StatusArgs -join ' ')"

        $VersionArgs = @('--version')
        $VersionCmd = "wsl $($VersionArgs -join ' ')"

        $DefaultOutputEncoding = [Console]::OutputEncoding

        # We can't immediately launch `wsl --version` as if WSL is available
        # but not installed it will prompt the user to press any key to start
        # the install with a 60 second time-out. Instead we can first use `wsl
        # --status` which seems to exit with code 50 when WSL is not installed.
        try {
            Write-Verbose -Message "Retrieving WSL status: ${StatusCmd}"
            [Console]::OutputEncoding = [Text.Encoding]::Unicode
            $null = & wsl @StatusArgs 2>&1
        } finally {
            [Console]::OutputEncoding = $DefaultOutputEncoding
        }

        switch ($LASTEXITCODE) {
            0 { } # Success

            50 {
                $ErrMsg = 'WSL is not installed.'
                $ErrCat = [Management.Automation.ErrorCategory]::NotInstalled
            }

            default {
                $ErrMsg = "Unknown exit code return by WSL: ${LASTEXITCODE}"
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            }
        }

        if ($LASTEXITCODE -ne 0) {
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $null)

            if ($Fatal) {
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $PSCmdlet.WriteError($ErrRec)
            return
        }

        try {
            Write-Verbose -Message "Retrieving WSL version: ${VersionCmd}"
            [Console]::OutputEncoding = [Text.Encoding]::Unicode
            $WslVersion = & wsl @VersionArgs 2>&1
        } finally {
            [Console]::OutputEncoding = $DefaultOutputEncoding
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warning -Message "WSL exited with non-zero exit code on requesting version details: ${LASTEXITCODE}"
        }

        $Result = [PSCustomObject]@{}
        foreach ($Line in $WslVersion) {
            if ([String]::IsNullOrWhiteSpace($Line)) { continue }

            if ($Line -notmatch '^([A-Za-z0-9]+) version: (.+)') {
                Write-Warning -Message "Unable to parse line in version output: ${Line}"
                continue
            }

            $Component = $Matches[1]
            $RawVersion = $Matches[2]

            $Version = $null
            if (![Version]::TryParse($RawVersion, [Ref]$Version)) {
                # Don't emit any warning or error as it's expected that some
                # WSL components will have versions not compatible with a
                # `Version` object.
                $Version = $RawVersion
            }

            $Result | Add-Member -MemberType 'NoteProperty' -Name $Component -Value $Version
        }

        if ($Result.PSObject.Properties.Name -contains 'WSL') {
            $Result | Add-Member -MemberType 'ScriptMethod' -Name 'ToString' -Value { $this.WSL } -Force
        } else {
            Write-Warning -Message 'No WSL version identified in version output.'
        }

        return $Result
    }

    if (!(Get-Command -Name 'wsl' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update WSL as wsl command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'wsl')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Result = [PSCustomObject]@{
        Success      = $false
        BeforeUpdate = ''
        AfterUpdate  = ''
        Output       = [String[]]@()
        ExitCode     = -1
        WhatIf       = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceWin.UpdateWSL')

    $UpdateArgs = @('--update')
    $UpdateCmd = "wsl $($UpdateArgs -join ' ')"

    $Result.BeforeUpdate = Get-WslVersion -Fatal

    if (!$PSCmdlet.ShouldProcess('WSL', 'Update')) {
        $Result.Success = $true
        $Result.WhatIf = $true
        return $Result
    }

    $DefaultOutputEncoding = [Console]::OutputEncoding

    try {
        Write-Verbose -Message "Updating WSL: ${UpdateCmd}"
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        $Result.Output = [String[]]@(& wsl @UpdateArgs 2>&1)
        $Result.ExitCode = $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $DefaultOutputEncoding
    }

    if ($Result.ExitCode -eq 0) {
        $Result.Success = $true
    } else {
        $ErrMsg = "WSL exited with non-zero exit code on performing update: $($Result.ExitCode)"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $null)
        $PSCmdlet.WriteError($ErrRec)
    }

    $Result.AfterUpdate = Get-WslVersion
    return $Result
}

Complete-DotFilesSection
