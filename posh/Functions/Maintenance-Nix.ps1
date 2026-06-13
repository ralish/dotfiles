$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Maintenance (Unix)'
    Platform = 'Unix'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Maintenance-Nix.format.ps1xml'))

# Update Homebrew, casks and formulae, and perform clean-up
#
# TODO: Add dependency cooldown support when available
Function Update-Homebrew {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    if (!(Get-Command -Name 'brew' -ErrorAction 'Ignore')) {
        $ErrMsg = 'Unable to update Homebrew as brew command not found.'
        $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, 'brew')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $WriteProgressParams = @{ Activity = 'Updating Homebrew' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Brew    = [String[]]@()
        Apps    = [String[]]@()
        Cleanup = [String[]]@()
        WhatIf  = $false
    }

    $Result.PSObject.TypeNames.Insert(0, 'DotFiles.MaintenanceNix.UpdateHomebrew')

    $UpdateBrewArgs = @('update')
    $UpdateBrewCmd = "brew $($UpdateBrewArgs -join ' ')"

    $UpgradeAppsArgs = @('upgrade')
    $UpgradeAppsCmd = "brew $($UpgradeAppsArgs -join ' ')"

    $CleanupArgs = 'cleanup', '-s'
    $CleanupCmd = "brew $($CleanupArgs -join ' ')"

    if ($PSCmdlet.ShouldProcess('Homebrew', 'Update')) {
        Write-Progress @WriteProgressParams -Status 'Updating Homebrew to latest version' -PercentComplete 1
        Write-Verbose -Message "Updating Homebrew: ${UpdateBrewCmd}"
        $Result.Brew = [String[]]@(& brew @UpdateBrewArgs 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Progress @WriteProgressParams -Completed

            $ErrMsg = "Homebrew update exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpdateBrewCmd)
            $PSCmdlet.WriteError($ErrRec)
            return $Result
        }
    }

    $DryrunMsg = ''
    if (!$PSCmdlet.ShouldProcess('Homebrew casks & formulae', 'Update')) {
        $DryrunMsg = ' (dry-run)'
        $UpgradeAppsArgs += '--dry-run'
        $UpgradeAppsCmd += ' --dry-run'
        $Result.WhatIf = $true
    }

    Write-Progress @WriteProgressParams -Status 'Updating casks & formulae' -PercentComplete 10
    Write-Verbose -Message "Updating Homebrew casks & formulae${DryrunMsg}: ${UpgradeAppsCmd}"
    $Result.Apps = [String[]]@(& brew @UpgradeAppsArgs 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Write-Progress @WriteProgressParams -Completed

        $ErrMsg = "Homebrew upgrade${DryrunMsg} exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $UpgradeAppsCmd)
        $PSCmdlet.WriteError($ErrRec)
        return $Result
    }

    $DryrunMsg = ''
    if (!$PSCmdlet.ShouldProcess('Homebrew outdated data', 'Remove')) {
        $DryrunMsg = ' (dry-run)'
        $CleanupArgs += '--dry-run'
        $CleanupCmd += ' --dry-run'
        $Result.WhatIf = $true
    }

    Write-Progress @WriteProgressParams -Status 'Cleaning-up outdated data' -PercentComplete 90
    Write-Verbose -Message "Cleaning-up outdated Homebrew data${DryrunMsg}: ${CleanupCmd}"
    $Result.Cleanup = [String[]]@(& brew @CleanupArgs 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Homebrew clean-up${DryrunMsg} exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $CleanupCmd)
        $PSCmdlet.WriteError($ErrRec)
    }

    Write-Progress @WriteProgressParams -Completed
    return $Result
}

Complete-DotFilesSection
