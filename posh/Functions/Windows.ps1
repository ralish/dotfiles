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
