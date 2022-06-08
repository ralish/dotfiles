Start-DotFilesSection -Type Functions -Name Development

#region .NET

# Retrieve available type accelerators
Function Get-TypeAccelerator {
    [CmdletBinding()]
    [OutputType([Collections.Generic.Dictionary[String, Type]])]
    Param()

    [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::get_Get()
}

# Retrieve the constructors for a given type
Function Get-TypeConstructor {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Type]$Type
    )

    Process {
        $Constructors = $Type.GetConstructors()
        foreach ($Constructor in $Constructors) {
            $ConstructorParams = $Constructor.GetParameters()
            if ($ConstructorParams.Count -gt 0) {
                $FormattedConstructorParams = @($ConstructorParams | ForEach-Object { $_.ToString() })
                $FormattedParams = '{0}({1})' -f $Type.FullName, ($FormattedConstructorParams -join ', ')
            } else {
                $FormattedParams = '{0}()' -f $Type.FullName
            }

            [PSCustomObject]@{
                Constructor = $FormattedParams
            }
        }
    }
}

# Retrieve the methods for a given type
Function Get-TypeMethod {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Type]$Type
    )

    Process {
        $Methods = $Type.GetMethods() | Sort-Object -Property Name
        foreach ($Method in $Methods) {
            $MethodParams = $Method.GetParameters()
            if ($MethodParams.Count -gt 0) {
                $FormattedMethodParams = @($MethodParams | ForEach-Object { $_.ToString() })
                $FormattedParams = '{0}({1})' -f $Type.FullName, ($FormattedMethodParams -join ', ')
            } else {
                $FormattedParams = '{0}()' -f $Type.FullName
            }

            [PSCustomObject]@{
                Method     = $Method.Name
                Parameters = $FormattedParams
            }
        }
    }
}

#endregion

#region Docker

# Clear Docker cache
Function Clear-DockerCache {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    if (!(Get-Command -Name docker -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to clear Docker cache as docker command not found.'
        return
    }

    $null = & docker system df
    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message 'Failed to retrieve Docker disk usage (is daemon running?).'
        return
    }

    if ($PSCmdlet.ShouldProcess('docker system prune', 'Clear')) {
        & docker system prune --force
    }
}

#endregion

#region Git

# Invoke a Git command in all Git repositories
Function Invoke-GitChildDir {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Command,

        [ValidateNotNullOrEmpty()]
        [Regex]$RepoInclude,

        [ValidateNotNullOrEmpty()]
        [Regex]$RepoExclude,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String[]]$Path,

        [Switch]$Recurse
    )

    Begin {
        $GitArgs = $Command.Split()
        $OriginalLocation = Get-Location

        if (!$Path) {
            $Path += $PWD.Path
        }
    }

    Process {
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

                if ($RepoInclude -and $SubDir.Name -notmatch $RepoInclude) {
                    Write-Verbose -Message ('Skipping repository not matching inclusion filter: {0}' -f $SubDir.Name)
                    continue
                }

                if ($RepoExclude -and $SubDir.Name -match $RepoExclude) {
                    Write-Verbose -Message ('Skipping repository matching exclusion filter: {0}' -f $SubDir.Name)
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
    }

    End {
        Set-Location -LiteralPath $OriginalLocation
    }
}

# Invoke a linter on matching repository files
Function Invoke-GitLinter {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
    [CmdletBinding()]
    [OutputType([Void], 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]', ParameterSetName = 'PSScriptAnalyzer')]
    [OutputType([Void], [String[]], ParameterSetName = 'ShellCheck')]
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
            if (!(Get-Command -Name Invoke-ScriptAnalyzer)) {
                throw 'Required command is unavailable: Invoke-ScriptAnalyzer'
            }

            $ScriptAnalyzerParams = @{
                Verbose = $false
            }

            if ($Settings) {
                $SettingsType = $Settings.GetType().FullName

                switch -Regex ($SettingsType) {
                    '^System\.(String|IO\.FileInfo)$' {
                        try {
                            $SettingsFile = Get-Item -LiteralPath $Settings -ErrorAction Stop
                        } catch {
                            throw $_
                        }

                        if ($SettingsFile -isnot [IO.FileInfo]) {
                            throw 'Provided settings path is not a file: {0}' -f $Settings
                        }
                    }

                    '^System\.Collections\.Hashtable$' { }

                    Default {
                        throw 'Settings parameter has unsupported type: {0}' -f $SettingsType
                    }
                }

                $ScriptAnalyzerParams['Settings'] = $Settings
            }

            $GitOutput = git ls-files
            if ($LASTEXITCODE -ne 0) { return }

            $GitOutput | Where-Object { $_ -match '\.ps[dm]?1$' } | ForEach-Object {
                if ($Exclude) {
                    if ($_ -match $Exclude) { return }
                }

                Write-Verbose -Message ('Invoking PSScriptAnalyzer on: {0}' -f $_)
                Invoke-ScriptAnalyzer -Path $_ @ScriptAnalyzerParams
            }
        }

        'ShellCheck' {
            if (!(Get-Command -Name shellcheck)) {
                throw 'Required command is unavailable: shellcheck'
            }

            if ($ShebangSearch -or $ShellDirectiveSearch) {
                if (!(Get-Command -Name rg)) {
                    throw 'Required command is unavailable: rg'
                }
            }

            $GitOutput = git ls-files
            if ($LASTEXITCODE -ne 0) { return }

            $Files = [Collections.Generic.List[String]]::new()
            $GitOutput | Where-Object { $_ -match '\.(ba)?sh$' } | ForEach-Object { $Files.Add($_) }

            if ($ShebangSearch) {
                rg --path-separator '/' --hidden -l '^#!/usr/bin/env (ba)?sh$' | ForEach-Object { $Files.Add($_) }
            }

            if ($ShellDirectiveSearch) {
                rg --path-separator '/' --hidden -l '#.*\bshellcheck\b.*\bshell=(ba)?sh\b' | ForEach-Object { $Files.Add($_) }
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
    [OutputType([Void], [String[]])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$SourceBranch
    )

    $GitOutput = git branch
    if ($LASTEXITCODE -ne 0) { return }

    if (!$SourceBranch) {
        $null = git rev-parse -q --verify main
        if ($LASTEXITCODE -eq 0) {
            $SourceBranch = 'main'
        } else {
            $null = git rev-parse -q --verify master
            if ($LASTEXITCODE -eq 0) {
                $SourceBranch = 'master'
            } else {
                throw 'Unable to guess source branch to merge.'
            }
        }
        Write-Verbose -Message ('Using guessed source branch: {0}' -f $SourceBranch)
    }

    $Branches = [Collections.Generic.List[String]]::new()
    foreach ($Branch in $GitOutput) {
        $Branches.Add($Branch.TrimStart('* '))
        if ($Branch.StartsWith('* ')) {
            $CurrentBranch = $Branch.TrimStart('* ')
        }
    }

    if ($SourceBranch -notin $Branches) {
        throw 'Source branch for merge not checked out: {0}' -f $SourceBranch
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

    if ($PSCmdlet.ShouldProcess($SourceBranch, 'Checkout')) {
        git checkout $SourceBranch
    }
}

# Remove a subset of paths returned from git-clean
Function Remove-GitCleanSubset {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        [Parameter(ValueFromPipeline)]
        [String[]]$GitCleanDryRunOutput,

        [ValidateNotNullOrEmpty()]
        [String[]]$RemovePaths = @('(^|/)bin/', '(^|/)obj/')
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

            foreach ($RemovalPath in $RemovePaths) {
                if ($Path -match $RemovalPath) {
                    Remove-Item -LiteralPath $Path -Recurse -Force
                    break
                }
            }
        }
    }
}

#endregion

Complete-DotFilesSection
