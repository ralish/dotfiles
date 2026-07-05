$DotFilesSection = @{
    Type    = 'Functions'
    Name    = 'Git'
    Command = 'git'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Print summary information about a Git repository
Function Global:Get-GitRepoSummary {
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

# Invoke a linter on matching repository files
Function Global:Invoke-GitLinter {
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
            try {
                Test-CommandAvailable -Name 'devskim'
            } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
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
                    $ExcMsg = 'The markdownlint-cli2 or markdownlint command must be available.'
                    $ErrExc = [Management.Automation.CommandNotFoundException]::new($ExcMsg)
                    $ErrExc.CommandName = $MdCliCmds -join ', '
                    $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandNotFound', $ErrCat, $MdlCliCmds)
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }
        }

        'PSScriptAnalyzer' {
            try {
                Test-CommandAvailable -Name 'Invoke-ScriptAnalyzer'
            } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

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
                            $ExcMsg = "Provided PSScriptAnalyzer settings path is not a file: ${Settings}"
                            $ErrExc = [ArgumentException]::new($ExcMsg, 'Settings')
                            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $SettingsFile)
                            $PSCmdlet.ThrowTerminatingError($ErrRec)
                        }
                    }

                    default {
                        $ExcMsg = "Settings parameter has unsupported type: ${SettingsType}"
                        $ErrExc = [ArgumentException]::new($ExcMsg, 'Settings')
                        $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Settings)
                        $PSCmdlet.ThrowTerminatingError($ErrRec)
                    }
                }

                $ScriptAnalyzerParams['Settings'] = $Settings
            }
        }

        'ShellCheck' {
            try {
                Test-CommandAvailable -Name 'shellcheck'

                if ($ShebangSearch -or $ShellDirectiveSearch) {
                    Test-CommandAvailable -Name 'rg'
                }
            } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
        }
    }

    $GitArgs = @('ls-files')
    $GitOutput = & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        $ExcMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = [Exception]::new($ExcMsg)
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
                if ($LASTEXITCODE -ge 2) {
                    $ExcMsg = "ripgrep exited with unexpected exit code: ${LASTEXITCODE}"
                    $ErrExc = [Exception]::new($ExcMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "rg $($RgArgs -join ' ')")
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }
            }

            if ($ShellDirectiveSearch) {
                $ShellDirective = '#.*\bshellcheck\b.*\bshell=(ba)?sh\b'
                $RgArgs = '--path-separator', '/', '--hidden', '-l', $ShellDirective
                & rg @RgArgs | ForEach-Object { $LintFiles.Add($PSItem) }
                if ($LASTEXITCODE -ge 2) {
                    $ExcMsg = "ripgrep exited with unexpected exit code: ${LASTEXITCODE}"
                    $ErrExc = [Exception]::new($ExcMsg)
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

    foreach ($LintFile in $LintFiles) {
        if ($ExcludePattern -and $LintFile -match $ExcludePattern) { continue }

        if (!(Test-Path -LiteralPath $LintFile -PathType 'Leaf')) {
            Write-Warning -Message "Skipping file missing from working tree: ${LintFile}"
            continue
        }

        if ($ExcludeSymlinks) {
            try {
                $File = Get-Item -LiteralPath $LintFile -Force -ErrorAction 'Stop'
                if ($File.LinkType -eq 'SymbolicLink') { continue }
            } catch {
                $PSCmdlet.WriteError($PSItem)
                continue
            }
        }

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
Function Global:Invoke-GitMergeAllBranches {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$SourceBranch
    )

    $null = & git symbolic-ref -q HEAD
    if ($LASTEXITCODE -ne 0) {
        $ExcMsg = 'Refusing to run while HEAD is detached.'
        $ErrExc = [Exception]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (!$SourceBranch) {
        $null = & git rev-parse -q --verify main 2>&1
        if ($LASTEXITCODE -eq 0) {
            $SourceBranch = 'main'
        } else {
            $null = & git rev-parse -q --verify master 2>&1
            if ($LASTEXITCODE -ne 0) {
                $ExcMsg = 'Unable to guess source branch to merge (not main or master).'
                $ErrExc = [Exception]::new($ExcMsg)
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
        $ExcMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
        $ErrExc = [Exception]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $CurrentBranch = $null
    $Branches = [Collections.Generic.List[String]]::new()
    foreach ($Branch in $GitOutput) {
        if ($Branch -notmatch '^[*+ ] \S') {
            $ExcMsg = 'Unexpected prefix for branch: "{0}"' -f $Branch
            $ErrExc = [FormatException]::new($ExcMsg)
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

    if ([String]::IsNullOrWhiteSpace($CurrentBranch)) {
        $ExcMsg = 'Repository has no current branch.'
        $ErrExc = [InvalidOperationException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NoCurrentBranch', $ErrCat, "git $($GitArgs -join ' ')")
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($SourceBranch -notin $Branches) {
        $ExcMsg = "Source branch for merge not checked out: ${SourceBranch}"
        $ErrExc = [Exception]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $SourceBranch)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if (($SourceBranch -ne $CurrentBranch) -and !$WhatIfPreference) {
        $GitArgs = 'checkout', $SourceBranch
        & git @GitArgs
        if ($LASTEXITCODE -ne 0) {
            $ExcMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ExcMsg)
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
                $ExcMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
                $ErrExc = [Exception]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $GitArgs = 'merge', '--ff-only', $SourceBranch
            & git @GitArgs
            if ($LASTEXITCODE -ne 0) {
                $ExcMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
                $ErrExc = [Exception]::new($ExcMsg)
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
            $ExcMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }
}

# Run a Git command in all repositories under a path
Function Global:Invoke-GitRepoCommand {
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
            $GitArgs = $GitCmd.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
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
                    $ExcMsg = "Skipping relative path as current path is not a file system: ${GitPath}"
                    $ErrExc = [ArgumentException]::new($ExcMsg, 'Path')
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
                $ExcMsg = "Path is not a directory: ${GitPath}"
                $ErrExc = [ArgumentException]::new($ExcMsg, 'Path')
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
                            $ExcMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
                            $ErrExc = [Exception]::new($ExcMsg)
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

# Remove a subset of paths returned by `git-clean`
Function Global:Remove-GitCleanSubset {
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
                $ExcMsg = "Path not in expected format: ${Line}"
                $ErrExc = [FormatException]::new($ExcMsg)
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
