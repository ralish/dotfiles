$DotFilesSection = @{
    Type    = 'Functions'
    Name    = 'Docker'
    Command = 'docker'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Clear Docker cache
Function Clear-DockerCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    $DockerArgs = 'system', 'df'
    $null = & docker @DockerArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve Docker disk usage (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "docker $($DockerArgs -join ' ')")
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $DockerArgs = 'system', 'prune', '--force'
    $DockerCmd = "docker $($DockerArgs -join ' ')"
    if ($PSCmdlet.ShouldProcess($DockerCmd, 'Clear')) {
        & docker @DockerArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Failed to clear Docker cache (rc: ${LASTEXITCODE})."
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $DockerCmd)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

Complete-DotFilesSection
