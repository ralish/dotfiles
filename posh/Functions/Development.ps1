#region .NET

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

#endregion

#region Git

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

# Fast-forward all branches to match a branch
Function Invoke-GitMergeAllBranches {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$SourceBranch='master'
    )

    $Branches = @()
    & git branch |
        ForEach-Object {
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

#endregion

#region VCS

# Create a file in each empty directory under a path
Function Add-FileToEmptyDirectories {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [ValidateNotNullOrEmpty()]
        [String[]]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$FileName='.keepme',

        [String[]]$Exclude=@('.git')
    )

    if (!$PSBoundParameters.ContainsKey('Path')) {
        $Path += Get-Item -Path $PWD.Path
    }

    foreach ($Dir in $Path) {
        $Dir = Get-Item -Path $Path -ErrorAction Ignore
        if ($Dir -isnot [IO.DirectoryInfo]) {
            Write-Error -Message ('Provided path is not a directory: {0}' -f $Path)
        }

        [Collections.ArrayList]$FilesToCreate = @()
        Get-ChildItem -Directory -Exclude $Exclude -Force | ForEach-Object {
            if ((Get-ChildItem -Path $_.FullName -Force | Measure-Object).Count -ne 0) {
                Get-ChildItem -Path $_.FullName -Directory -Recurse -Force | ForEach-Object {
                    if ((Get-ChildItem -Path $_.FullName -Force | Measure-Object).Count -eq 0) {
                        $null = $FilesToCreate.Add((Join-Path -Path $_.FullName -ChildPath $FileName))
                    }
                }
            } else {
                $null = $FilesToCreate.Add((Join-Path -Path $_.FullName -ChildPath $FileName))
            }
        }

        foreach ($FilePath in $FilesToCreate) {
            if ($PSCmdlet.ShouldProcess($FilePath, 'Create')) {
                $null = New-Item -Path $FilePath -ItemType File -Verbose
            }
        }
    }
}

#endregion
