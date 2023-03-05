$DotFilesSection = @{
    Type     = 'Functions'
    Name     = 'Maintenance (Unix)'
    Platform = 'Unix'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Update Homebrew & installed apps
Function Update-Homebrew {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [PSCustomObject])]
    Param(
        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

    if (!(Get-Command -Name 'brew' -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to update Homebrew as brew command not found.'
        return
    }

    $WriteProgressParams = @{
        Activity = 'Updating Homebrew'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    $Result = [PSCustomObject]@{
        Update  = $null
        Upgrade = $null
        Cleanup = $null
    }

    [String[]]$UpdateArgs = 'update'
    [String[]]$UpgradeArgs = 'upgrade'
    [String[]]$CleanupArgs = 'cleanup', '-s'
    if ($WhatIfPreference) {
        $UpgradeArgs += '--dry-run'
        $CleanupArgs += '--dry-run'
    }

    if ($WhatIfPreference -or $PSCmdlet.ShouldProcess('Homebrew', 'Update')) {
        Write-Progress @WriteProgressParams -Status 'Updating Homebrew' -PercentComplete 1
        Write-Verbose -Message ('Updating Homebrew: brew {0}' -f ($UpdateArgs -join ' '))
        $Result.Update = & brew @UpdateArgs
    }

    if ($WhatIfPreference -or $PSCmdlet.ShouldProcess('Homebrew casks & formulae', 'Update')) {
        Write-Progress @WriteProgressParams -Status 'Updating casks & formulae' -PercentComplete 20
        Write-Verbose -Message ('Updating casks & formulae: brew {0}' -f ($UpgradeArgs -join ' '))
        $Result.Upgrade = & brew @UpgradeArgs
    }

    if ($WhatIfPreference -or $PSCmdlet.ShouldProcess('Homebrew obsolete files', 'Remove')) {
        Write-Progress @WriteProgressParams -Status 'Cleaning-up obsolete files' -PercentComplete 80
        Write-Verbose -Message ('Cleaning-up obsolete files: brew {0}' -f ($CleanupArgs -join ' '))
        $Result.Cleanup = & brew @CleanupArgs
    }

    Write-Progress @WriteProgressParams -Completed

    return $Result
}

Complete-DotFilesSection
