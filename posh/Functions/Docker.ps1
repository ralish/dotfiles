$DotFilesSection = @{
    Type    = 'Functions'
    Name    = 'Docker'
    Command = 'docker'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Clear Docker cache
Function Global:Clear-DockerCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    $DfArgs = 'system', 'df'
    $DfCmd = "docker $($DfArgs -join ' ')"

    $PruneArgs = 'system', 'prune', '--force'
    $PruneCmd = "docker $($PruneArgs -join ' ')"

    Write-Verbose -Message "Retrieving Docker disk usage: ${DfCmd}"
    $null = & docker @DfArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $ExcMsg = "Failed to retrieve Docker disk usage (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $DfCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($PSCmdlet.ShouldProcess($PruneCmd, 'Clear')) {
        Write-Verbose -Message "Clearing Docker caches: ${PruneCmd}"
        & docker @PruneArgs
        if ($LASTEXITCODE -ne 0) {
            $ExcMsg = "Failed to clear Docker cache (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PruneCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

Complete-DotFilesSection
