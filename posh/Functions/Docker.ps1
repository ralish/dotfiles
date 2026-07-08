$DotFilesSection = @{
    Type    = 'Functions'
    Name    = 'Docker'
    Command = 'docker'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Clear Docker data
Function Global:Clear-DockerData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([Void], [String[]])]
    Param(
        [Switch]$All,
        [Switch]$Volumes,
        [Switch]$Force
    )

    # Confirmation is handled natively in PowerShell (so `--force` is safe)
    $PruneArgs = 'system', 'prune', '--force'

    # Remove all unused images (not just dangling ones)
    if ($All) {
        $PruneArgs += '--all'
    }

    # Remove anonymous volumes
    if ($Volumes) {
        $PruneArgs += '--volumes'
    }

    $PruneCmd = "docker $($PruneArgs -join ' ')"

    # Skip confirmation with `-Force` unless `-Confirm` was provided
    if ($Force -and !$PSBoundParameters.ContainsKey('Confirm')) {
        $ConfirmPreference = 'None'
    }

    if ($PSCmdlet.ShouldProcess('Docker data', 'Clear')) {
        Write-Verbose -Message "Clearing Docker data: ${PruneCmd}"
        & docker @PruneArgs
        if ($LASTEXITCODE -ne 0) {
            $ExcMsg = "Failed to clear Docker data (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $PruneCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

Complete-DotFilesSection
