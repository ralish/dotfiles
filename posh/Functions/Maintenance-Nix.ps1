$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Maintenance (Unix)'
    Platform = 'Unix'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Maintenance-Nix.format.ps1xml'))

# Update Homebrew, casks & formulae, and perform clean-up
#
# TODO: Add dependency cooldown support when available
Function Update-Homebrew {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Get-Command -Name 'brew' -ErrorAction Ignore)) {
        throw 'Unable to update Homebrew as brew command not found.'
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

    $UpdateBrewArgs = [String[]]@('update')
    $UpgradeAppsArgs = [String[]]@('upgrade')
    $CleanupArgs = [String[]]@('cleanup', '-s')

    if ($PSCmdlet.ShouldProcess('Homebrew', 'Update')) {
        Write-Progress @WriteProgressParams -Status 'Updating Homebrew to latest version' -PercentComplete 1
        Write-Verbose -Message ('Updating Homebrew: brew {0}' -f ($UpdateBrewArgs -join ' '))

        try {
            $Result.Brew = [String[]]@(& brew @UpdateBrewArgs 2>&1)
        } catch {
            $LASTEXITCODE = -1
            $Msg = 'Failed to start Homebrew update: {0}' -f $PSItem.Exception.Message
            $Result.Brew = [String[]]@($Msg)
            Write-Eror -Message $Msg
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message ('Homebrew update returned non-zero exit code: {0}' -f $LASTEXITCODE)
            Write-Progress @WriteProgressParams -Completed
            return $Result
        }
    }

    $DryrunMsg += ''
    if (!$PSCmdlet.ShouldProcess('Homebrew casks & formulae', 'Update')) {
        $UpgradeAppsArgs += '--dry-run'
        $DryrunMsg += ' (dry-run)'
        $Result.WhatIf = $true
    }

    Write-Progress @WriteProgressParams -Status 'Updating casks & formulae' -PercentComplete 10
    Write-Verbose -Message ('Updating Homebrew casks & formulae{0}: brew {1}' -f $DryrunMsg, ($UpgradeAppsArgs -join ' '))

    try {
        $Result.Apps = [String[]]@(& brew @UpgradeAppsArgs 2>&1)
    } catch {
        $LASTEXITCODE = -1
        $Msg = 'Failed to start Homebrew upgrade{0}: {1}' -f $DryrunMsg, $PSItem.Exception.Message
        $Result.Apps = [String[]]@($Msg)
        Write-Eror -Message $Msg
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message ('Homebrew upgrade{0} returned non-zero exit code: {1}' -f $DryrunMsg, $LASTEXITCODE)
        Write-Progress @WriteProgressParams -Completed
        return $Result
    }

    $DryrunMsg = ''
    if (!$PSCmdlet.ShouldProcess('Homebrew outdated data', 'Remove')) {
        $CleanupArgs += '--dry-run'
        $DryrunMsg = ' (dry-run)'
        $Result.WhatIf = $true
    }

    Write-Progress @WriteProgressParams -Status 'Cleaning-up outdated data' -PercentComplete 90
    Write-Verbose -Message ('Cleaning-up outdated Homebrew data{0}: brew {1}' -f $DryrunMsg, ($CleanupArgs -join ' '))

    try {
        $Result.Cleanup = [String[]]@(& brew @CleanupArgs 2>&1)
    } catch {
        $LASTEXITCODE = -1
        $Msg = 'Failed to start Homebrew clean-up{0}: {1}' -f $DryrunMsg, $PSItem.Exception.Message
        $Result.Cleanup = [String[]]@($Msg)
        Write-Eror -Message $Msg
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message ('Homebrew clean-up{0} returned non-zero exit code: {1}' -f $DryrunMsg, $LASTEXITCODE)
    }

    Write-Progress @WriteProgressParams -Completed
    return $Result
}

Complete-DotFilesSection
