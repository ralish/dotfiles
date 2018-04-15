# Watch an Event Log (similar to Unix "tail")
# Slightly improved from: http://stackoverflow.com/questions/15262196/powershell-tail-windows-event-log-is-it-possible
Function Get-EventLogTail {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$EventLog
    )

    $IndexOld = (Get-EventLog -LogName $EventLog -Newest 1).Index
    do {
        Start-Sleep -Seconds 1
        $IndexNew = (Get-EventLog -LogName $EventLog -Newest 1).Index
        if ($IndexNew -ne $IndexOld) {
            Get-EventLog -LogName $EventLog -Newest ($IndexNew - $IndexOld) | Sort-Object -Property Index
            $IndexOld = $IndexNew
        }
    } while ($true)
}

# Retrieve files with a minimum number of hard links
Function Get-MultipleHardLinks {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$Path,

        [ValidateScript({$_ -gt 1})]
        [Int]$MinimumHardLinks=2,

        [Switch]$Recurse
    )

    $Files = Get-ChildItem -Path $Path -File -Recurse:$Recurse | Where-Object {
        $_.LinkType -eq 'HardLink' -and $_.Target.Count -ge ($MinimumHardLinks - 1)
    } | Add-Member -MemberType ScriptProperty -Name LinkCount -Value { $this.Target.Count + 1 } -Force

    return $Files
}

# Retrieve directories with non-inherited ACLs
Function Get-NonInheritedACLs {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$User,

        [Switch]$Recurse
    )

    $Directories = Get-ChildItem -Path $Path -Directory -Recurse:$Recurse

    $ACLMatches = @()
    foreach ($Directory in $Directories) {
        $ACL = Get-ACL -Path $Directory.FullName
        $ACLNonInherited = $ACL.Access | Where-Object { $_.IsInherited -eq $false }

        if (!$ACLNonInherited) {
            continue
        }

        if ($PSBoundParameters.ContainsKey('User')) {
            if ($ACLNonInherited.IdentityReference -notcontains $User) {
                continue
            }
        }

        $ACLMatches += $Directory
    }

    return $ACLMatches
}

# Helper function to call MKLINK in cmd
Function mklink {
    & $env:ComSpec /c mklink $args
}
