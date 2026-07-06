$DotFilesSection = @{
    Type    = 'Functions'
    Name    = 'Docker'
    Command = 'docker'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Clear Docker data
Function Global:Clear-DockerData {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param(
        [Switch]$All,
        [Switch]$Volumes
    )

    $PruneArgs = 'system', 'prune', '--force'

    if ($All) {
        $PruneArgs += '--all'
    }

    if ($Volumes) {
        $PruneArgs += '--volumes'
    }

    $PruneCmd = "docker $($PruneArgs -join ' ')"

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
