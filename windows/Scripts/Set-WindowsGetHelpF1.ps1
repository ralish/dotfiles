<#
    Enable/Disable the F1 key opening a web browser to search for "How to get
    help" on Bing.
#>

#Requires -Version 5.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
[OutputType([Void])]
Param(
    [Parameter(Mandatory)]
    [ValidateSet('Enable', 'Disable')]
    [String]$Operation
)

if ([Environment]::OSVersion.Version.Major -lt 10) {
    $ErrMsg = 'Script is only valid for Windows 10 or later.'
    $ErrExc = [PlatformNotSupportedException]::new($ErrMsg)
    $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'OSNotSupported', $ErrCat, $null)
    $PSCmdlet.ThrowTerminatingError($ErrRec)
}

$Architectures = @('win32')
if ([Environment]::Is64BitOperatingSystem) {
    $Architectures += 'win64'
}

$RemoveHKCRDrive = $false
if (!(Get-PSDrive -Name 'HKCR' -ErrorAction 'Ignore')) {
    $RemoveHKCRDrive = $true
    $null = New-PSDrive -Name 'HKCR' -PSProvider 'Registry' -Root 'HKEY_CLASSES_ROOT' -WhatIf:$false
}

try {
    foreach ($Architecture in $Architectures) {
        $RegSubKeyPath = "TypeLib\{8cec5860-07a1-11d9-b15e-000d56bfe6ee}\1.0\0\${Architecture}"
        $RegPath = "HKCR:\${RegSubKeyPath}"

        try {
            # Extremely slow as it enumerates all keys as it traverses the path
            $null = Get-Item -LiteralPath $RegPath -ErrorAction 'Stop'
        } catch {
            Write-Warning -Message "Failed to retrieve ${Architecture} registry key for AP Client 1.0 Type Library."
            continue
        }

        try {
            $RegKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($RegSubKeyPath, $true)
            $UpdateRegKeySecurity = $false
            $RegKey.Close()
        } catch {
            $UpdateRegKeySecurity = $true
        }

        try {
            $RestoreRegKeySecurity = $false

            if ($UpdateRegKeySecurity -and $PSCmdlet.ShouldProcess($RegPath, 'Update ACL')) {
                # Cheeky but much easier than doing it through the Win32 API
                $NtDllImport = '[DllImport("ntdll.dll")] public static extern int RtlAdjustPrivilege(ulong Privilege, bool Enable, bool CurrentThread, ref bool PreviousValue);'
                $NtDll = Add-Type -MemberDefinition $NtDllImport -Name 'NtDll' -PassThru

                # Enable required privileges
                $Privileges = @{ SeTakeOwnership = 9; SeBackup = 17; SeRestore = 18 }
                foreach ($Privilege in $Privileges.Keys) {
                    $Result = $NtDll::RtlAdjustPrivilege($Privileges[$Privilege], $true, $false, [Ref]$null)
                    if ($Result -ne 0) {
                        $ErrMsg = "Failed calling RtlAdjustPrivilege to enable ${Privilege} privilege (NTSTATUS: ${Result})."
                        $ErrExc = [Exception]::new($ErrMsg)
                        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeApiFailed', $ErrCat, $Result)
                        $PSCmdlet.ThrowTerminatingError($ErrRec)
                    }
                }

                # Save original ACL
                # `-LiteralPath` is broken on at least Windows PowerShell 5.1
                $RegKeyOriginalAcl = Get-Acl -Path $RegPath -ErrorAction 'Stop'

                # Update the owner
                $UserNTAccount = [Security.Principal.NTAccount]([Security.Principal.WindowsIdentity]::GetCurrent().Name)
                $RegKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($RegSubKeyPath,
                    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                    [Security.AccessControl.RegistryRights]::TakeOwnership)
                $RegKeyAcl = $RegKey.GetAccessControl([Security.AccessControl.AccessControlSections]::Owner)
                $RegKeyAcl.SetOwner($UserNTAccount)
                $RestoreRegKeySecurity = $true
                $RegKey.SetAccessControl($RegKeyAcl)
                $RegKey.Close()

                # Grant full control
                $RegKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($RegSubKeyPath,
                    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                    [Security.AccessControl.RegistryRights]::ChangePermissions)
                $RegKeyAcl = $RegKey.GetAccessControl()
                $RegKeyAce = [Security.AccessControl.RegistryAccessRule]::new($UserNTAccount,
                    [Security.AccessControl.RegistryRights]::FullControl,
                    [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',
                    [Security.AccessControl.PropagationFlags]::None,
                    [Security.AccessControl.AccessControlType]::Allow)
                $RegKeyAcl.SetAccessRule($RegKeyAce)
                $RegKey.SetAccessControl($RegKeyAcl)
                $RegKey.Close()
            }

            if ($Operation -eq 'Enable') {
                if ($PSCmdlet.ShouldProcess($RegPath, 'Enable F1 key opening web browser search for help')) {
                    try {
                        $HelpPanePath = Join-Path -Path $Env:SystemRoot -ChildPath 'HelpPane.exe'
                        Set-ItemProperty -LiteralPath $RegPath -Name '(default)' -Type 'String' -Value $HelpPanePath -ErrorAction 'Stop'
                    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
                }
            } elseif ($PSCmdlet.ShouldProcess($RegPath, 'Disable F1 key opening web browser search for help')) {
                try {
                    # `Remove-ItemProperty` doesn't seem to support deleting
                    # the `(default)` value, so we use this alternate approach.
                    $RegKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($RegSubKeyPath, $true)
                    $RegKey.DeleteValue('', $false)
                    $RegKey.Close()
                } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
            }
        } finally {
            if ($RestoreRegKeySecurity -and $PSCmdlet.ShouldProcess($RegPath, 'Restore ACL')) {
                # Restore original ACL
                $AclSections = [Security.AccessControl.AccessControlSections]::Owner -bor [Security.AccessControl.AccessControlSections]::Group -bor [Security.AccessControl.AccessControlSections]::Access
                $RegKeyAcl = [Security.AccessControl.RegistrySecurity]::new()
                $RegKeyAcl.SetSecurityDescriptorSddlForm($RegKeyOriginalAcl.Sddl, $AclSections)
                # `-LiteralPath` is broken on at least Windows PowerShell 5.1
                $RegKeyAcl | Set-Acl -Path $RegPath
            }
        }
    }
} finally {
    if ($RemoveHKCRDrive) {
        Remove-PSDrive -Name 'HKCR' -WhatIf:$false
    }
}
