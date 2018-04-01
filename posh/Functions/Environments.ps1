# Prepend Node.js directories to PATH variable
Function Enable-Nodejs {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Path
    )

    $LocalNpmPath = Join-Path -Path $Env:APPDATA -ChildPath 'npm'
    Set-Item -Path Env:\Path -Value ('{0};{1};{2}' -f $LocalNpmPath, $Path, $Env:PATH)
}

# Prepend Perl directories to PATH variable
Function Enable-Perl {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Path
    )

    $RootBinPath = Join-Path -Path $Path -ChildPath 'c\bin'
    $SiteBinPath = Join-Path -Path $Path -ChildPath 'perl\site\bin'
    $PerlBinPath = Join-Path -Path $Path -ChildPath 'perl\bin'
    Set-Item -Path Env:\Path -Value ('{0};{1};{2};{3}' -f $RootBinPath, $SiteBinPath, $PerlBinPath, $Env:PATH)
}

# Prepend Python directories to PATH variable
Function Enable-Python {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Path
    )

    $ScriptsPath = Join-Path -Path $Path -ChildPath 'Scripts'
    Set-Item -Path Env:\Path -Value ('{0};{1};{2}' -f $ScriptsPath, $Path, $Env:PATH)
}
