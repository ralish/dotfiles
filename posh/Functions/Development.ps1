# Invoke a Git command in all Git repositories
Function Invoke-GitChildDir {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Command,

        [ValidateNotNullOrEmpty()]
        [String]$Path
    )

    $GitArgs = $Command.Split()

    if (!$Path) {
        $Path = Get-Location -PSProvider FileSystem
    }

    $OrigLocation = Get-Location
    Set-Location -Path $Path

    $Dirs = Get-ChildItem -Directory
    foreach ($Dir in $Dirs) {
        $GitDir = Join-Path -Path $Dir -ChildPath '.git'
        if (-not (Test-Path -Path $GitDir -PathType Container)) {
            Write-Verbose -Message ('Skipping directory: {0}' -f $Dir.Name)
            continue
        }

        Write-Host -ForegroundColor Green -Object ('Running in: {0}' -f $Dir.Name)
        Set-Location -Path $Dir
        & git @GitArgs
        Set-Location -Path $Path
        Write-Host
    }

    Set-Location -Path $OrigLocation
}
