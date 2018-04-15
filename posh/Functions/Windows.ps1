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

Function Get-NonInheritedACLs {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$User
    )

    $ACLMatches = @()
    $Directories = Get-ChildItem -Path $Path -Directory -Recurse

    foreach ($Directory in $Directories) {
        $ACL = Get-ACL -Path $Directory.FullName
        $ACLNonInherited = $ACL.Access | Where-Object { $_.IsInherited -eq $false }

        if ($ACLNonInherited.IdentityReference -contains $User) {
            $ACLMatches += $Directory
        }
    }

    return $ACLMatches
}
