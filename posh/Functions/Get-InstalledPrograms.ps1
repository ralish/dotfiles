# Fetch the list of installed software on a system via the Registry
# This is effectively a PS implementation of Programs and Features
# Useful on Server Core installs where there's no built-in cmdlet
Function Get-InstalledPrograms {
    $NativeRegPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $Wow6432RegPath = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'

    # Get the list of installed programs including WOW64 if present
    $UninstKeys = Get-ItemProperty $NativeRegPath
    if (Test-Path $Wow6432RegPath -PathType Container) {
        $UninstKeys += Get-ItemProperty $Wow6432RegPath
    }

    # Define the default display information to be used for our custom object
    $defaultDisplaySet = 'Name', 'Publisher', 'Version'
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

    $InstProgs = @()
    foreach  ($Prog in $UninstKeys) {
        # If the entry has no defined DisplayName ignore it as it's probably not useful
        if ($Prog.DisplayName -ne $null) {
            $ProgInfo = [PsCustomObject]@{
                Name = $Prog.DisplayName
                Publisher = $Prog.Publisher
                InstalledOn = $Prog.InstallDate
                Size = $Prog.EstimatedSize
                Version = $Prog.DisplayVersion
                Location = $Prog.InstallLocation
                Uninstall = $Prog.UninstallString
            }
            $ProgInfo | Add-Member MemberSet PSStandardMembers $PSStandardMembers
            $InstProgs += $ProgInfo
        }
    }
    return $InstProgs
}
