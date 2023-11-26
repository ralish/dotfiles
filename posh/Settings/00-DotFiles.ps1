$DotFilesSection = @{
    Type     = 'Settings'
    Name     = 'dotfiles'
    Platform = 'Windows'
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

Function Initialize-DotFiles {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if (!('DotFiles.FinalPath' -as [Type])) {
        $FinalPathCode = Join-Path -Path $PoshSettingsPath -ChildPath '00-DotFiles.cs'
        $FinalPathAPI = Get-Content -LiteralPath $FinalPathCode -Raw
        Add-Type -Namespace 'DotFiles' -Name 'FinalPath' -MemberDefinition $FinalPathAPI
    }

    Write-Debug -Message (Get-DotFilesMessage -Message 'Opening handle to PowerShell profile directory ...')
    $ProfileDirPath = Split-Path -Path $PROFILE -Parent
    $ProfileDirHandle = [DotFiles.FinalPath]::CreateFile($ProfileDirPath, 0, 0, 0, [DotFiles.FinalPath+CreateFileCreationDisposition]::OPEN_EXISTING, [DotFiles.FinalPath+CreateFileFlagsAndAttributes]::FILE_FLAG_BACKUP_SEMANTICS, 0)
    if ($ProfileDirHandle -eq [DotFiles.FinalPath]::INVALID_HANDLE_VALUE) {
        throw [ComponentModel.Win32Exception]::new()
    }

    Write-Debug -Message (Get-DotFilesMessage -Message 'Retrieving final path to PowerShell profile directory ...')
    $ProfileDirFinalPath = [Text.StringBuilder]::new(1023)
    $Result = [DotFiles.FinalPath]::GetFinalPathNameByHandle($ProfileDirHandle, $ProfileDirFinalPath, $ProfileDirFinalPath.Capacity + 1, [DotFiles.FinalPath+GetFinalPathNameByHandleFlags]::VOLUME_NAME_DOS)
    if ($Result -eq 0) {
        throw [ComponentModel.Win32Exception]::new()
    } elseif ($Result -gt ($ProfileDirFinalPath.Capacity + 1)) {
        Write-Error -Message ('Final path to PowerShell profile directory exceeds string buffer size of {0}: {1}' -f ($Result - 1), $ProfileDirFinalPath.Capacity)
    }

    Write-Debug -Message (Get-DotFilesMessage -Message 'Closing PowerShell profile directory handle ...')
    if (![DotFiles.FinalPath]::CloseHandle($ProfileDirHandle)) {
        throw [ComponentModel.Win32Exception]::new()
    }

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    $Global:DotFiles = Split-Path -Path $ProfileDirFinalPath.ToString().TrimStart('\', '?') -Parent
}

Initialize-DotFiles

Remove-Item -Path 'Function:\Initialize-DotFiles'
Complete-DotFilesSection
