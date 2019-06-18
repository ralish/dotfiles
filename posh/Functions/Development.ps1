# Retrieve available type accelerators
Function Get-TypeAccelerator {
    [CmdletBinding()]
    Param()

    [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::get_Get()
}

# Retrieve the constructors for a given type
Function Get-TypeConstructor {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Type]$Type
    )

    $Constructors = $Type.GetConstructors()
    foreach ($Constructor in $Constructors) {
        $ConstructorParams = $Constructor.GetParameters()
        if ($ConstructorParams.Count -gt 0) {
            $FormattedParams = '{0}({1})' -f $Type.FullName, [String]::Join(', ', ($ConstructorParams | ForEach-Object { $_.ToString() }))
        } else {
            $FormattedParams = '{0}()' -f $Type.FullName
        }

        [PSCustomObject]@{
            Constructor = $FormattedParams
        }
    }
}

# Retrieve the methods for a given type
Function Get-TypeMethod {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Type]$Type
    )

    $Methods = $Type.GetMethods() | Sort-Object -Property Name
    foreach ($Method in $Methods) {
        $MethodParams = $Method.GetParameters()
        if ($MethodParams.Count -gt 0) {
            $FormattedParams = '{0}({1})' -f $Type.FullName, [String]::Join(', ', ($MethodParams | ForEach-Object { $_.ToString() }))
        } else {
            $FormattedParams = '{0}()' -f $Type.FullName
        }

        [PSCustomObject]@{
            Method      = $Method.Name
            Parameters  = $FormattedParams
        }
    }
}

# Invoke a Git command in all Git repositories
Function Invoke-GitChildDir {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Command,

        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [Switch]$Recurse
    )

    $GitArgs = $Command.Split()

    if (!$Path) {
        $Path = Get-Location -PSProvider FileSystem
    }

    $OrigLocation = Get-Location
    Set-Location -Path $Path -ErrorAction Stop
    $BaseLocation = Get-Location

    $Dirs = Get-ChildItem -Directory
    foreach ($Dir in $Dirs) {
        $GitDir = Join-Path -Path $Dir -ChildPath '.git'
        if (-not (Test-Path -Path $GitDir -PathType Container)) {
            if ($Recurse) {
                Invoke-GitChildDir -Command $Command -Path $Dir.FullName -Recurse:$Recurse
            } else {
                Write-Verbose -Message ('Skipping directory: {0}' -f $Dir.Name)
            }
            continue
        }

        Write-Host -ForegroundColor Green -Object ('Running in: {0}' -f $Dir.Name)
        Set-Location -Path $Dir
        & git @GitArgs
        Set-Location -Path $BaseLocation
        Write-Host
    }

    Set-Location -Path $OrigLocation
}

Function Invoke-GitMergeAllBranches {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$SourceBranch='master'
    )

    $Branches = @()
    & git branch | ForEach-Object {
        $Branches += $_.TrimStart('* ')
        if ($_.StartsWith('* ')) {
            $CurrentBranch = $_.TrimStart('* ')
        }
    }

    if ($SourceBranch -notin $Branches) {
        throw ('Source branch for merge does not exist locally: {0}' -f $SourceBranch)
    }

    if ($SourceBranch -ne $CurrentBranch) {
        & git checkout $SourceBranch
        Write-Host ''
    }

    foreach ($Branch in $Branches) {
        if ($Branch -eq $SourceBranch) {
            continue
        }

        Write-Host -ForegroundColor Green ('Updating branch: {0}' -f $Branch)
        & git checkout $Branch
        & git merge --ff-only $SourceBranch
        Write-Host ''
    }

    & git checkout $SourceBranch
}
