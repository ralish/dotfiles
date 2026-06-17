$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'dotfiles'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Retrieve `dotfiles` directory path resolving all symlinks and junctions
Function Get-DotFilesFinalPath {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if (!('DotFiles.FinalPath' -as [Type])) {
        $FinalPathCode = Join-Path -Path $PoshSettingsPath -ChildPath '00-DotFiles.cs'
        $FinalPathAPI = Get-Content -LiteralPath $FinalPathCode -Raw
        Add-Type -TypeDefinition $FinalPathAPI
    }

    Write-Debug -Message (Get-DotFilesMessage -Message 'Opening handle to PowerShell profile directory ...')
    $ProfileDirPath = Split-Path -Path $PROFILE -Parent
    $ProfileDirHandle = [DotFiles.FinalPath]::CreateFile($ProfileDirPath, 0, 0, 0, [DotFiles.FinalPath+CreateFileCreationDisposition]::OPEN_EXISTING, [DotFiles.FinalPath+CreateFileFlagsAndAttributes]::FILE_FLAG_BACKUP_SEMANTICS, 0)
    if ($ProfileDirHandle -eq [DotFiles.FinalPath]::INVALID_HANDLE_VALUE) {
        $ErrExc = [ComponentModel.Win32Exception]::new()
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'Win32ApiFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        Write-Debug -Message (Get-DotFilesMessage -Message 'Retrieving final path to PowerShell profile directory ...')
        $ProfileDirFinalPath = [Text.StringBuilder]::new(1023)
        # The `Capacity + 1` is because the marshaler allocates a buffer with
        # an extra character to account for a terminating null. The native
        # `StringBuilder` does not store strings with a null-terminator.
        $Result = [DotFiles.FinalPath]::GetFinalPathNameByHandle($ProfileDirHandle, $ProfileDirFinalPath, $ProfileDirFinalPath.Capacity + 1, [DotFiles.FinalPath+GetFinalPathNameByHandleFlags]::VOLUME_NAME_DOS)
        if ($Result -eq 0) {
            $ErrExc = [ComponentModel.Win32Exception]::new()
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'Win32ApiFailed', $ErrCat, $null)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        # Failure is indicated by a return value greater than the buffer size
        # including the terminating null and represents the required buffer
        # size including the null terminator.
        if ($Result -gt ($ProfileDirFinalPath.Capacity + 1)) {
            $ErrMsg = "Final path to PowerShell profile directory exceeds string buffer size of $($ProfileDirFinalPath.Capacity): $($Result - 1)"
            $ErrExc = [ComponentModel.Win32Exception]::new(122, $ErrMsg) # ERROR_INSUFFICIENT_BUFFER
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeApiFailed', $ErrCat, $Result)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $Global:DotFiles = Split-Path -Path $ProfileDirFinalPath.ToString().TrimStart('\', '?') -Parent
        Write-Verbose -Message (Get-DotFilesMessage -Message "Final path of dotfiles directory: ${Global:DotFiles}")
    } finally {
        Write-Debug -Message (Get-DotFilesMessage -Message 'Closing PowerShell profile directory handle ...')
        if (![DotFiles.FinalPath]::CloseHandle($ProfileDirHandle)) {
            $ErrExc = [ComponentModel.Win32Exception]::new()
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'Win32ApiFailed', $ErrCat, $null)
            $PSCmdlet.WriteError($ErrRec)
        }
    }
}

Get-DotFilesFinalPath

Remove-Item -LiteralPath 'Function:\Get-DotFilesFinalPath'
Complete-DotFilesSection
