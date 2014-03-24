# Customise our prompt for useful Git status info (needs posh-git)
if (Get-Module posh-git) {
    Function global:prompt {
        $REALLASTEXITCODE = $LASTEXITCODE

        # Reset colour as it can be messed up by Enable-GitColors
        $Host.UI.RawUI.ForegroundColor = $GitPromptSettings.DefaultForegroundColor

        Write-Host ($pwd.ProviderPath) -NoNewline
        Write-VcsStatus

        $global:LASTEXITCODE = $REALLASTEXITCODE
        return '> '
    }
}

# Neatly print out all users with UIDs (uses RFC2307 schema extensions)
Function Get-ADUserUID {
    Get-ADUser -Filter { uidNumber -ge 10000 } -Properties uidNumber, sAMAccountName, name, mail, loginShell, unixHomeDirectory, gidNumber `
     | Sort-Object -Property uidNumber `
     | Format-Table -Property uidNumber, sAMAccountName, name, mail, loginShell, unixHomeDirectory, gidNumber
}

# Neatly print out all groups with GIDs (uses RFC2307 schema extensions)
Function Get-ADGroupGID {
    Get-ADGroup -Filter { gidNumber -ge 10000 } -Properties gidNumber, sAMAccountName, memberUid `
     | Sort-Object -Property gidNumber `
     | Format-Table -Property gidNumber, sAMAccountName, memberUid
}

# Watch a nominated Windows Event Log (in a similar fashion to "tail")
# Slightly improved from: http://stackoverflow.com/questions/15262196/powershell-tail-windows-event-log-is-it-possible
Function Get-EventLogTail {
    Param(
        [Parameter(Mandatory=$true)]
            [String]$EventLog
    )

    $idx1 = (Get-EventLog -LogName $EventLog -Newest 1).Index
    do {
        Start-Sleep -Seconds 1
        $idx2 = (Get-EventLog -LogName $EventLog -Newest 1).Index
        Get-EventLog -LogName $EventLog -Newest ($idx2 - $idx1) | Sort Index
        $idx1 = $idx2
    } while ($true)
}

# Quick and dirty method to get the list of installed software
# Useful on Server Core installs where there's no simple cmdlet
Function Get-InstalledPrograms {
    $NativeRegPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $Wow6432RegPath = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'

    $InstProgs = Get-ItemProperty $NativeRegPath
    if (Test-Path $Wow6432RegPath) {
        $InstProgs += Get-ItemProperty $Wow6432RegPath
    }
    return $InstProgs
}

# The MKLINK command is actually part of the Command Processor (cmd.exe)
# So we have a quick and dirty function below to invoke it via PowerShell
Function mklink {
    cmd /c mklink $args
}
