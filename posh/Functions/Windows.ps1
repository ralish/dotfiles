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
