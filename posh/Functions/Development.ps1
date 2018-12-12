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
