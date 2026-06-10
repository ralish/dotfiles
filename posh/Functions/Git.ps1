$DotFilesSection = @{
    Type    = 'Functions'
    Name    = 'Git'
    Command = 'git'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Print summary information about a Git repository
Function Get-GitRepoSummary {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String[]]$Path,

        [Switch]$Recurse
    )

    Begin {
        if (!$Path) {
            $Path += $PWD.Path
        }
    }

    Process {
        $GitCmds = @(
            'status --short --branch'
            'remote -v'
            '--no-pager branch -vv'
        )

        $Path | Invoke-GitRepoCommand -Command $GitCmds -Recurse:$Recurse
    }
}

# Run a Git command in all repositories under a path
Function Invoke-GitRepoCommand {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Command,

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
        $OriginalLocation = Get-Location

        if (!$Path) {
            $Path += $PWD.Path
        }

        $GitCmds = [Collections.Generic.List[String[]]]::new()
        foreach ($GitCmd in $Command) {
            $GitArgs = $GitCmd.Split()
            $GitCmds.Add($GitArgs)
        }

        $RecurseParams = @{
            Command = $Command
            Recurse = $Recurse
        }

        if ($PSBoundParameters.ContainsKey('RepoInclude')) {
            $RecurseParams['RepoInclude'] = $RepoInclude
        }

        if ($PSBoundParameters.ContainsKey('RepoExclude')) {
            $RecurseParams['RepoExclude'] = $RepoExclude
        }
    }

    Process {
        foreach ($GitPath in $Path) {
            if (!(Test-IsPathFullyQualified -Path $GitPath)) {
                if ($OriginalLocation.Provider.Name -ne 'FileSystem') {
                    $ErrMsg = "Skipping relative path as current path is not a file system: ${GitPath}"
                    $ErrExc = [ArgumentException]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $GitPath)
                    $PSCmdlet.WriteError($ErrRec)
                    continue
                }

                $GitPath = Join-Path -Path $OriginalLocation -ChildPath $GitPath
            }

            try {
                $BaseDir = Get-Item -LiteralPath $GitPath -ErrorAction 'Stop'
            } catch {
                $PSCmdlet.WriteError($PSItem)
                continue
            }

            if ($BaseDir -isnot [IO.DirectoryInfo]) {
                $ErrMsg = "Path is not a directory: ${GitPath}"
                $ErrExc = [ArgumentException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $GitPath)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            $GitDirs = [Collections.Generic.List[IO.DirectoryInfo]]::new()
            $GitDir = Join-Path -Path $BaseDir.FullName -ChildPath '.git'
            if (Test-Path -LiteralPath $GitDir -PathType 'Container') {
                $GitDirs.Add($BaseDir)
            } else {
                $SubDirs = Get-ChildItem -LiteralPath $BaseDir.FullName -Directory

                foreach ($SubDir in $SubDirs) {
                    $GitDir = Join-Path -Path $SubDir.FullName -ChildPath '.git'

                    if (!(Test-Path -LiteralPath $GitDir -PathType 'Container')) {
                        if ($Recurse) {
                            Invoke-GitRepoCommand -Path $SubDir.FullName @RecurseParams
                        } else {
                            Write-Verbose -Message "Skipping directory: $($SubDir.Name)"
                        }

                        continue
                    }

                    if ($RepoInclude -and $SubDir.Name -notmatch $RepoInclude) {
                        Write-Verbose -Message "Skipping repository not matching inclusion filter: $($SubDir.Name)"
                        continue
                    }

                    if ($RepoExclude -and $SubDir.Name -match $RepoExclude) {
                        Write-Verbose -Message "Skipping repository matching exclusion filter: $($SubDir.Name)"
                        continue
                    }

                    $GitDirs.Add($SubDir)
                }
            }

            $GitDirsProcessed = 0
            foreach ($GitDir in $GitDirs) {
                $GitDirsProcessed++

                if ($PSCmdlet.ShouldProcess($GitDir.Name, 'Invoke Git command')) {
                    try {
                        Write-Host -ForegroundColor 'Green' "Running in: $($GitDir.Name)"
                        Set-Location -LiteralPath $GitDir.FullName -ErrorAction 'Stop'
                    } catch {
                        $PSCmdlet.WriteError($PSItem)
                        continue
                    }

                    foreach ($GitCmd in $GitCmds) {
                        & git @GitCmd
                        if ($LASTEXITCODE -ne 0) {
                            $ErrMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
                            $ErrExc = [Exception]::new($ErrMsg)
                            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitCmd -join ' ')")
                            $PSCmdlet.WriteError($ErrRec)
                        }
                    }

                    if ($GitDirsProcessed -lt $GitDirs.Count) {
                        Write-Host
                    }
                }
            }
        }
    }

    End {
        try {
            Set-Location -LiteralPath $OriginalLocation -ErrorAction 'Stop'
        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }
}

# Invoke a linter on matching repository files
Function Invoke-GitLinter {
    [CmdletBinding()]
    [OutputType(ParameterSetName = ('DevSkim', 'Markdownlint', 'ShellCheck'), [Void], [String[]])]
    [OutputType(ParameterSetName = 'PSScriptAnalyzer', 'Void', 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]')]
    Param(
        [Parameter(ParameterSetName = 'DevSkim', Mandatory)]
        [Switch]$DevSkim,

        [Parameter(ParameterSetName = 'Markdownlint', Mandatory)]
        [Switch]$Markdownlint,

        [Parameter(ParameterSetName = 'PSScriptAnalyzer', Mandatory)]
        [Switch]$PSScriptAnalyzer,

        # `String`, `IO.FileInfo`, or `Collections.Hashtable`
        [Parameter(ParameterSetName = 'PSScriptAnalyzer')]
        [PSObject]$Settings,

        [Parameter(ParameterSetName = 'ShellCheck', Mandatory)]
        [Switch]$ShellCheck,

        [Parameter(ParameterSetName = 'ShellCheck')]
        [Switch]$ShebangSearch,

        [Parameter(ParameterSetName = 'ShellCheck')]
        [Switch]$ShellDirectiveSearch,

        [Regex]$ExcludePattern,
        [Switch]$ExcludeSymlinks
    )

    switch ($PSCmdlet.ParameterSetName) {
        'DevSkim' {
            Test-CommandAvailable -Name 'devskim'
        }

        'Markdownlint' {
            $MdlCliCmds = 'markdownlint-cli2', 'markdownlint'

            try {
                Test-CommandAvailable -Name 'markdownlint-cli2'

                $MdlCliCmd = $MdlCliCmds[0]
            } catch {
                try {
                    Test-CommandAvailable -Name 'markdownlint'

                    $MdlCliCmd = $MdlCliCmds[1]
                } catch {
                    $ErrMsg = 'The markdownlint-cli2 or markdownlint command must be available.'
                    $ErrExc = [Management.Automation.CommandNotFoundException]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, $MdlCliCmds)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }
        }

        'PSScriptAnalyzer' {
            Test-CommandAvailable -Name 'Invoke-ScriptAnalyzer'

            $ScriptAnalyzerParams = @{ Verbose = $false }

            if ($Settings) {
                $SettingsType = $Settings.GetType().FullName

                switch -Regex ($SettingsType) {
                    '^System\.Collections\.Hashtable$' { }

                    '^System\.(String|IO\.FileInfo)$' {
                        try {
                            $SettingsFile = Get-Item -LiteralPath $Settings -ErrorAction 'Stop'
                        } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

                        if ($SettingsFile -isnot [IO.FileInfo]) {
                            $ErrMsg = "Provided PSScriptAnalyzer settings path is not a file: ${Settings}"
                            $ErrExc = [ArgumentException]::new($ErrMsg)
                            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $SettingsFile)
                            $PSCmdlet.ThrowTerminatingError($ErrRec)
                        }
                    }

                    default {
                        $ErrMsg = "Settings parameter has unsupported type: ${SettingsType}"
                        $ErrExc = [ArgumentException]::new($ErrMsg)
                        $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Settings)
                        $PSCmdlet.ThrowTerminatingError($ErrRec)
                    }
                }

                $ScriptAnalyzerParams['Settings'] = $Settings
            }
        }

        'ShellCheck' {
            Test-CommandAvailable -Name 'shellcheck'

            if ($ShebangSearch -or $ShellDirectiveSearch) {
                Test-CommandAvailable -Name 'rg'
            }
        }
    }

    $GitArgs = @('ls-files')
    $GitOutput = & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    switch ($PSCmdlet.ParameterSetName) {
        'Markdownlint' {
            $LintFiles = $GitOutput | Where-Object { $PSItem -match '\.md$' }
        }

        'PSScriptAnalyzer' {
            $LintFiles = $GitOutput | Where-Object { $PSItem -match '\.ps[dm]?1$' }
        }

        'ShellCheck' {
            $LintFiles = [Collections.Generic.List[String]]::new()
            $GitOutput | Where-Object { $PSItem -match '\.(ba)?sh$' } | ForEach-Object { $LintFiles.Add($PSItem) }

            if ($ShebangSearch) {
                $Shebang = '^#!/usr/bin/env (ba)?sh$'
                $RgArgs = '--path-separator', '/', '--hidden', '-l', $Shebang
                & rg @RgArgs | ForEach-Object { $LintFiles.Add($PSItem) }
                if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
                    $ErrMsg = "ripgrep exited with unexpected exit code: ${LASTEXITCODE}"
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "rg $($RgArgs -join ' ')")
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }

            if ($ShellDirectiveSearch) {
                $ShellDirective = '#.*\bshellcheck\b.*\bshell=(ba)?sh\b'
                $RgArgs = '--path-separator', '/', '--hidden', '-l', $ShellDirective
                & rg @RgArgs | ForEach-Object { $LintFiles.Add($PSItem) }
                if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
                    $ErrMsg = "ripgrep exited with unexpected exit code: ${LASTEXITCODE}"
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "rg $($RgArgs -join ' ')")
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }

            if ($ShebangSearch -or $ShellDirectiveSearch) {
                $LintFiles = $LintFiles | Sort-Object -Unique
            }
        }

        default { $LintFiles = $GitOutput }
    }

    if ($ExcludePattern) {
        $LintFiles = $LintFiles | Where-Object { $PSItem -notmatch $ExcludePattern }
    }

    if ($ExcludeSymlinks) {
        $LintFiles = $LintFiles | Where-Object { (Get-Item -LiteralPath $PSItem -Force).LinkType -ne 'SymbolicLink' }
    }

    foreach ($LintFile in $LintFiles) {
        switch ($PSCmdlet.ParameterSetName) {
            'DevSkim' {
                Write-Verbose -Message "Invoking DevSkim on: ${LintFile}"
                $DevSkimArgs = 'analyze', '-I', $LintFile, '-o', '%F:%L [%S] %R %N'
                & devskim @DevSkimArgs
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning -Message "DevSkim exited with non-zero exit code: ${LASTEXITCODE}"
                }
            }

            'Markdownlint' {
                Write-Verbose -Message "Invoking ${MdlCliCmd} on: ${LintFile}"
                $MdCliArgs = @($LintFile)
                & $MdlCliCmd @MdCliArgs
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning -Message "${MdlCliCmd} exited with non-zero exit code: ${LASTEXITCODE}"
                }
            }

            'PSScriptAnalyzer' {
                Write-Verbose -Message "Invoking PSScriptAnalyzer on: ${LintFile}"
                Invoke-ScriptAnalyzer -Path $LintFile @ScriptAnalyzerParams | Where-Object {
                    # HACK: The statement alignment rule does horrible things
                    # to the `PSScriptAnalyzer` hashtable, but the suppression
                    # facility doesn't work for `.psd1` files.
                    $PSItem.ScriptName -ne 'PSScriptAnalyzerSettings.psd1' -and
                    $PSItem.RuleName -ne 'PSAlignAssignmentStatement'
                }
            }

            'ShellCheck' {
                Write-Verbose -Message "Invoking ShellCheck on: ${LintFile}"
                $ShellCheckArgs = '-x', $LintFile
                & shellcheck @ShellCheckArgs
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning -Message "shellcheck exited with non-zero exit code: ${LASTEXITCODE}"
                }
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

    if (!$SourceBranch) {
        $null = & git rev-parse -q --verify main 2>&1
        if ($LASTEXITCODE -eq 0) {
            $SourceBranch = 'main'
        } else {
            $null = & git rev-parse -q --verify master 2>&1
            if ($LASTEXITCODE -ne 0) {
                $ErrMsg = 'Unable to guess source branch to merge (not main or master).'
                $ErrExc = [Exception]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $null)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $SourceBranch = 'master'
        }

        Write-Verbose -Message "Using guessed source branch: ${SourceBranch}"
    }

    $GitArgs = @('branch')
    $GitOutput = & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $CurrentBranch = $null
    $Branches = [Collections.Generic.List[String]]::new()
    foreach ($Branch in $GitOutput) {
        if ($Branch -notmatch '^[*+ ] \S') {
            $ErrMsg = 'Unexpected prefix for branch: "{0}"' -f $Branch
            $ErrExc = [FormatException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ParserError
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $Branch)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $Branch = $Branch.Trim()
        if ($Branch.StartsWith('* ')) {
            $Branch = $Branch -replace '^\* '
            $CurrentBranch = $Branch
        } elseif ($Branch.StartsWith('+ ')) {
            $Branch = $Branch -replace '^\+ '
        }

        $Branches.Add($Branch)
    }

    if ([String]::IsNullOrEmpty($CurrentBranch)) {
        $ErrMsg = 'Repository has no current branch.'
        $ErrExc = [InvalidOperationException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NoCurrentBranch', $ErrCat, "git $($GitArgs -join ' ')")
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($SourceBranch -notin $Branches) {
        $ErrMsg = "Source branch for merge not checked out: ${SourceBranch}"
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $SourceBranch)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (($SourceBranch -ne $CurrentBranch) -and !$WhatIfPreference) {
        $GitArgs = 'checkout', $SourceBranch
        & git @GitArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        Write-Host
    }

    foreach ($Branch in $Branches) {
        if ($Branch -eq $SourceBranch) { continue }

        if ($PSCmdlet.ShouldProcess($Branch, "Merge ${SourceBranch}")) {
            Write-Host -ForegroundColor 'Green' "Updating branch: ${Branch}"

            $GitArgs = 'checkout', $Branch
            & git @GitArgs
            if ($LASTEXITCODE -ne 0) {
                $ErrMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
                $ErrExc = [Exception]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $GitArgs = 'merge', '--ff-only', $SourceBranch
            & git @GitArgs
            if ($LASTEXITCODE -ne 0) {
                $ErrMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
                $ErrExc = [Exception]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            Write-Host
        }
    }

    if (!$WhatIfPreference) {
        $GitArgs = 'checkout', $CurrentBranch
        & git @GitArgs
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Remove a subset of paths returned by `git-clean`
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
                Write-Warning -Message "Ignoring repository at path: $($Matches[1])"
                continue
            }

            if ($Line -notmatch '^Would remove (.+)') {
                $ErrMsg = "Path not in expected format: ${Line}"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::ParserError
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $Line)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            $Path = $Matches[1]
            foreach ($RemovalPath in $RemovePaths) {
                if ($Path -match $RemovalPath) {
                    # Handles `-Confirm` / `-WhatIf`
                    Remove-Item -LiteralPath $Path -Recurse -Force
                    break
                }
            }
        }
    }
}

Complete-DotFilesSection
