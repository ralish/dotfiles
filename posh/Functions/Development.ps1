if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing development functions ...')

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
            Method     = $Method.Name
            Parameters = $FormattedParams
        }
    }
}

#endregion

#region Git

# Invoke a Git command in all Git repositories
Function Invoke-GitChildDir {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory)]
        [String]$Command,

        [ValidateNotNullOrEmpty()]
        [String[]]$Path,

        [Switch]$Recurse
    )

    if (!$PSBoundParameters.ContainsKey('Path')) {
        $Path += $PWD.Path
    }

    $GitArgs = $Command.Split()
    $OriginalLocation = Get-Location

    foreach ($Item in $Path) {
        $IsPathFullyQualified = [IO.Path]::IsPathFullyQualified($Item)

        if ($OriginalLocation.Provider.Name -ne 'FileSystem' -and !$IsPathFullyQualified) {
            Write-Error -Message ('Skipping relative path as current path is not a file system: {0}' -f $Item)
            continue
        }

        if (!$IsPathFullyQualified) {
            try {
                Set-Location -LiteralPath $OriginalLocation -ErrorAction Stop
            } catch {
                throw $_
            }
        }

        try {
            $BaseDir = Get-Item -LiteralPath $Item -ErrorAction Stop
        } catch {
            Write-Error -Message $_.Message
            continue
        }

        if ($BaseDir -isnot [IO.DirectoryInfo]) {
            Write-Error -Message ('Provided path is not a directory: {0}' -f $Item)
            continue
        }

        $SubDirs = Get-ChildItem -LiteralPath $BaseDir.FullName -Directory
        foreach ($SubDir in $SubDirs) {
            $GitDir = Join-Path -Path $SubDir.FullName -ChildPath '.git'
            if (-not (Test-Path -LiteralPath $GitDir -PathType Container)) {
                if ($Recurse) {
                    Invoke-GitChildDir -Path $SubDir.FullName -Command $Command -Recurse:$Recurse
                } else {
                    Write-Verbose -Message ('Skipping directory: {0}' -f $SubDir.Name)
                }
                continue
            }

            if ($PSCmdlet.ShouldProcess($SubDir.Name, 'Invoke Git command')) {
                Write-Host -ForegroundColor Green ('Running in: {0}' -f $SubDir.Name)
                Set-Location -LiteralPath $SubDir.FullName
                git @GitArgs
                Set-Location -LiteralPath $BaseDir.FullName
                Write-Host
            }
        }
    }

    Set-Location -LiteralPath $OriginalLocation
}

# Invoke a linter on matching repository files
Function Invoke-GitLinter {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName = 'PSScriptAnalyzer', Mandatory)]
        [Switch]$PSScriptAnalyzer,

        [Parameter(ParameterSetName = 'PSScriptAnalyzer')]
        [Object]$Settings,

        [Parameter(ParameterSetName = 'ShellCheck', Mandatory)]
        [Switch]$ShellCheck,

        [Parameter(ParameterSetName = 'ShellCheck')]
        [Switch]$ShebangSearch,

        [Parameter(ParameterSetName = 'ShellCheck')]
        [Switch]$ShellDirectiveSearch,

        [Regex]$Exclude
    )

    switch ($PSCmdlet.ParameterSetName) {
        'PSScriptAnalyzer' {
            if (!(Get-Command -Name 'Invoke-ScriptAnalyzer')) {
                Write-Error -Message 'Required command is unavailable: Invoke-ScriptAnalyzer'
                return
            }

            $ScriptAnalyzerParams = @{
                Verbose = $false
            }

            if ($Settings) {
                $ScriptAnalyzerParams['Settings'] = $Settings
            }

            $GitOutput = git ls-files
            if ($LASTEXITCODE -ne 0) { return }

            $GitOutput | Where-Object { $_ -match '\.ps[dm]?1$' } | ForEach-Object {
                if ($PSBoundParameters.ContainsKey('Exclude')) {
                    if ($_ -match $Exclude) { return }
                }

                Write-Verbose -Message ('Invoking PSScriptAnalyzer on: {0}' -f $_)
                Invoke-ScriptAnalyzer -Path $_ @ScriptAnalyzerParams
            }
        }

        'ShellCheck' {
            if (!(Get-Command -Name 'shellcheck')) {
                Write-Error -Message 'Required command is unavailable: shellcheck'
                return
            }

            if ($ShebangSearch -or $ShellDirectiveSearch) {
                if (!(Get-Command -Name 'rg')) {
                    Write-Error -Message 'Required command is unavailable: rg'
                    return
                }
            }

            $GitOutput = git ls-files
            if ($LASTEXITCODE -ne 0) { return }

            $Files = [Collections.ArrayList]::new()
            $GitOutput | Where-Object { $_ -match '\.(ba)?sh$' } | ForEach-Object { $null = $Files.Add($_) }

            if ($ShebangSearch) {
                rg --path-separator '/' --hidden -l '^#!/usr/bin/env (ba)?sh$' | ForEach-Object { $null = $Files.Add($_) }
            }

            if ($ShellDirectiveSearch) {
                rg --path-separator '/' --hidden -l '#.*\bshellcheck\b.*\bshell=(ba)?sh\b' | ForEach-Object { $null = $Files.Add($_) }
            }

            if ($ShebangSearch -or $ShellDirectiveSearch) {
                $FoundFiles = $Files
                $Files = $FoundFiles | Sort-Object -Unique
            }

            $Files | ForEach-Object {
                Write-Verbose -Message ('Invoking ShellCheck on: {0}' -f $_)
                shellcheck -x $_
            }
        }
    }
}

# Fast-forward all branches to match a branch
Function Invoke-GitMergeAllBranches {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$SourceBranch
    )

    $GitOutput = git branch
    if ($LASTEXITCODE -ne 0) { return }

    if (!$PSBoundParameters.ContainsKey('SourceBranch')) {
        $null = git rev-parse -q --verify main
        if ($LASTEXITCODE -eq 0) {
            $SourceBranch = 'main'
        } else {
            $null = git rev-parse -q --verify master
            if ($LASTEXITCODE -eq 0) {
                $SourceBranch = 'master'
            } else {
                Write-Error -Message 'Unable to guess source branch to merge.'
                return
            }
        }
        Write-Verbose -Message ('Using guessed source branch: {0}' -f $SourceBranch)
    }

    $Branches = [Collections.ArrayList]::new()
    foreach ($Branch in $GitOutput) {
        $null = $Branches.Add($Branch.TrimStart('* '))
        if ($Branch.StartsWith('* ')) {
            $CurrentBranch = $Branch.TrimStart('* ')
        }
    }

    if ($SourceBranch -notin $Branches) {
        Write-Error -Message ('Source branch for merge not checked out: {0}' -f $SourceBranch)
        return
    }

    if ($SourceBranch -ne $CurrentBranch) {
        git checkout $SourceBranch
        if ($LASTEXITCODE -ne 0) { return }
        Write-Host
    }

    foreach ($Branch in $Branches) {
        if ($Branch -eq $SourceBranch) {
            continue
        }

        if ($PSCmdlet.ShouldProcess($Branch, 'Merge {0}' -f $SourceBranch)) {
            Write-Host -ForegroundColor Green ('Updating branch: {0}' -f $Branch)
            git checkout $Branch
            if ($LASTEXITCODE -ne 0) { return }
            git merge --ff-only $SourceBranch
            if ($LASTEXITCODE -ne 0) { return }
            Write-Host
        }
    }

    git checkout $SourceBranch
}

#endregion

#region VCS

# Create a file in each empty directory under a path
Function Add-FileToEmptyDirectories {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [ValidateNotNullOrEmpty()]
        [String[]]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$FileName = '.keepme',

        # Non-recursive (only direct descendents)
        [String[]]$Exclude = '.git'
    )

    if (!$PSBoundParameters.ContainsKey('Path')) {
        $Path += $PWD.Path
    }

    $CurrentLocation = Get-Location

    foreach ($Item in $Path) {
        if ($CurrentLocation.Provider.Name -ne 'FileSystem' -and ![IO.Path]::IsPathFullyQualified($Item)) {
            Write-Error -Message ('Skipping relative path as current path is not a file system: {0}' -f $Item)
            continue
        }

        try {
            $DirPath = Get-Item -LiteralPath $Item -Force:$Force -ErrorAction Stop
        } catch {
            Write-Error -Message $_.Message
            continue
        }

        if ($DirPath -isnot [IO.DirectoryInfo]) {
            Write-Error -Message ('Provided path is not a directory: {0}' -f $Item)
            continue
        }

        $FilesToCreate = [Collections.ArrayList]::new()
        Get-ChildItem -LiteralPath $DirPath.FullName -Directory -Exclude $Exclude -Force:$Force | ForEach-Object {
            if ((Get-ChildItem -LiteralPath $_.FullName -Force:$Force | Measure-Object).Count -ne 0) {
                Get-ChildItem -LiteralPath $_.FullName -Directory -Recurse -Force:$Force | ForEach-Object {
                    if ((Get-ChildItem -LiteralPath $_.FullName -Force:$Force | Measure-Object).Count -eq 0) {
                        # Subdirectory (not top-level) with no children
                        $null = $FilesToCreate.Add((Join-Path -Path $_.FullName -ChildPath $FileName))
                    }
                }
            } else {
                # Top-level subdirectory (minus exclusions) with no children
                $null = $FilesToCreate.Add((Join-Path -Path $_.FullName -ChildPath $FileName))
            }
        }

        foreach ($FilePath in $FilesToCreate) {
            $null = New-Item -Path $FilePath -ItemType File -Verbose
        }
    }
}

# Remove a subset of paths returned from git-clean
Function Remove-GitCleanSubset {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(ValueFromPipeline)]
        [String[]]$GitCleanDryRunOutput,

        [ValidateNotNullOrEmpty()]
        [String[]]$RemovePathsEndingWith = @('/bin/', '/obj/')
    )

    Process {
        foreach ($Line in $GitCleanDryRunOutput) {
            if ($Line -match '^Would skip repository (.+)') {
                Write-Warning -Message ('Ignoring repository at path: {0}' -f $Matches[1])
                continue
            }

            if ($Line -notmatch '^Would remove (.+)') {
                Write-Error -Message ('Path not in expected format: {0}' -f $Line)
                continue
            }

            $Path = $Matches[1]

            foreach ($RemovalPath in $RemovePathsEndingWith) {
                if ($Path.EndsWith($RemovalPath)) {
                    Remove-Item -LiteralPath $Path -Recurse -Force
                    break
                }
            }
        }
    }
}

#endregion
