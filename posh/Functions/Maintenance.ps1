$null = Start-DotFilesSection -Type 'Functions' -Name 'Maintenance'

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Maintenance.format.ps1xml'))

# Retrieves a report containing:
# - Name and version for all vendored components
# - Path and last reviewed version for all configuration files
Function Get-DotFilesLastUpdated {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    Param()

    Test-CommandAvailable -Name 'git', 'rg'

    try {
        Push-Location
        Set-Location -LiteralPath $DotFiles -ErrorAction 'Stop'

        # Exclude the `.git` directory
        $RgGlobExcludeGit = '!.git/'

        # Exclude the file containing this function from being matched by `rg`
        $RgGlobExcludeThis = "!$([IO.Path]::GetFileName($PSCommandPath))"

        $RgArgs = '--hidden', '-g', $RgGlobExcludeGit, '-g', $RgGlobExcludeThis, 'Last reviewed release: '
        $LastReviewedReleases = & rg @RgArgs
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
            $ErrMsg = "ripgrep exited with unexpected exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "rg $($RgArgs -join ' ')")
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $GitArgs = @('ls-files')
        $LastReviewedVersions = & git @GitArgs | Where-Object { $PSItem -match '[\\/]VERSION$' }
        if ($LASTEXITCODE -ne 0) {
            $ErrMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $ComponentVersions = [Collections.Generic.List[PSCustomObject]]::new()

        foreach ($LastReviewedRelease in $LastReviewedReleases) {
            if ($LastReviewedRelease -notmatch '^(.+):.*Last reviewed release: (.+)') {
                $ErrMsg = "Unexpected match returned by rg: ${LastReviewedRelease}"
                $ErrExc = [FormatException]::new($ErrMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::ParserError
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $LastReviewedRelease)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            $Result = [PSCustomObject]@{
                Name    = $Matches[1]
                Version = $Matches[2]
            }

            if ($Result.Version -match '^v[0-9]') {
                $Result.Version = $Result.Version.Substring(1)
            }

            $ComponentVersions.Add($Result)
        }

        foreach ($LastReviewedVersion in $LastReviewedVersions) {
            $ComponentDir = [IO.Path]::GetDirectoryName($LastReviewedVersion)
            $ComponentName = [IO.Path]::GetFileName($ComponentDir)
            $Version = Get-Content -LiteralPath $LastReviewedVersion -TotalCount 1

            if ([String]::IsNullOrEmpty($Version)) {
                $Version = '(empty)'
            } elseif ($Version -match '^v[0-9]') {
                $Version = $Version.Substring(1)
            }

            $Result = [PSCustomObject]@{
                Name    = $ComponentName
                Version = $Version
            }

            $ComponentVersions.Add($Result)
        }
    } finally {
        Pop-Location
    }

    return [PSCustomObject[]]@($ComponentVersions | Sort-Object -Property 'Name')
}

# Clear caches used by development environments and tooling
Function Clear-AllDevCaches {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(DefaultParameterSetName = 'OptOut', SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(ParameterSetName = 'OptOut')]
        [ValidateSet(
            'Docker',
            'gem',
            'Go',
            'Gradle',
            'Maven',
            'npm',
            'NuGet',
            'pip'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName = 'OptIn', Mandatory)]
        [ValidateSet(
            'Docker',
            'gem',
            'Go',
            'Gradle',
            'Maven',
            'npm',
            'NuGet',
            'pip'
        )]
        [String[]]$IncludeTasks
    )

    $ValidTasks = @(
        'Docker'
        'gem'
        'Go'
        'Gradle'
        'Maven'
        'npm'
        'NuGet'
        'pip'
    )

    $WriteProgressParams = @{
        Id       = 0
        Activity = 'Clearing caches for development environments & tooling'
    }

    $Tasks = [Collections.Generic.List[String]]::new()
    $TasksDone = 0
    $TasksTotal = 0

    foreach ($Task in $ValidTasks) {
        if (($PSCmdlet.ParameterSetName -eq 'OptOut' -and $ExcludeTasks -notcontains $Task) -or
            ($PSCmdlet.ParameterSetName -eq 'OptIn' -and $IncludeTasks -contains $Task)) {
            $Tasks.Add($Task)
            $TasksTotal++
        }
    }

    Write-Verbose -Message "Clearing caches for: $($Tasks -join ', ')"

    if ($Tasks -contains 'Docker') {
        Write-Progress @WriteProgressParams -Status 'Clearing Docker cache' -PercentComplete ($TasksDone / $TasksTotal * 100)

        try {
            Clear-DockerCache
        } catch { $PSCmdlet.WriteError($PSItem) }

        $TasksDone++
    }

    if ($Tasks -contains 'gem') {
        Write-Progress @WriteProgressParams -Status 'Clearing gem cache' -PercentComplete ($TasksDone / $TasksTotal * 100)

        try {
            Clear-GemCache
        } catch { $PSCmdlet.WriteError($PSItem) }

        $TasksDone++
    }

    if ($Tasks -contains 'Go') {
        Write-Progress @WriteProgressParams -Status 'Clearing Go cache' -PercentComplete ($TasksDone / $TasksTotal * 100)

        try {
            Clear-GoCache
        } catch { $PSCmdlet.WriteError($PSItem) }

        $TasksDone++
    }

    if ($Tasks -contains 'Gradle') {
        Write-Progress @WriteProgressParams -Status 'Clearing Gradle cache' -PercentComplete ($TasksDone / $TasksTotal * 100)

        try {
            Clear-GradleCache
        } catch { $PSCmdlet.WriteError($PSItem) }

        $TasksDone++
    }

    if ($Tasks -contains 'Maven') {
        Write-Progress @WriteProgressParams -Status 'Clearing Maven cache' -PercentComplete ($TasksDone / $TasksTotal * 100)

        try {
            Clear-MavenCache
        } catch { $PSCmdlet.WriteError($PSItem) }

        $TasksDone++
    }

    if ($Tasks -contains 'npm') {
        Write-Progress @WriteProgressParams -Status 'Clearing npm cache' -PercentComplete ($TasksDone / $TasksTotal * 100)

        try {
            Clear-NpmCache
        } catch { $PSCmdlet.WriteError($PSItem) }

        $TasksDone++
    }

    if ($Tasks -contains 'NuGet') {
        Write-Progress @WriteProgressParams -Status 'Clearing NuGet cache' -PercentComplete ($TasksDone / $TasksTotal * 100)

        try {
            Clear-NuGetCache
        } catch { $PSCmdlet.WriteError($PSItem) }

        $TasksDone++
    }

    if ($Tasks -contains 'pip') {
        Write-Progress @WriteProgressParams -Status 'Clearing pip cache' -PercentComplete ($TasksDone / $TasksTotal * 100)

        try {
            Clear-PipCache
        } catch { $PSCmdlet.WriteError($PSItem) }

        $TasksDone++
    }

    Write-Progress @WriteProgressParams -Completed
}

# Update everything!
Function Update-AllTheThings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(DefaultParameterSetName = 'OptOut', SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param()

    DynamicParam {
        $AllCategories = 'System', 'Apps', 'Devel'
        $CategoryVsa = [Management.Automation.ValidateSetAttribute]::new([String[]]($AllCategories | Sort-Object))

        $TasksApps = @('PowerShell')
        $TasksDevel = 'DotNetTools', 'GoBinaries', 'NodejsPackages', 'PythonPipPackages', 'PythonPipxPackages', 'RubyGems', 'RustToolchains'
        $TasksSystem = @()

        if (Test-IsWindows) {
            $TasksApps = @('Office', 'VisualStudio') + $TasksApps + @('MicrosoftStore', 'Edge', 'Chrome', 'WinGet', 'Scoop')
            $TasksDevel = ($TasksDevel + @('Python', 'QtComponents')) | Sort-Object
            $TasksSystem += 'Windows', 'WSL'
        } else {
            $TasksApps += 'Homebrew'
        }

        $AllTasks = $TasksApps + $TasksDevel + $TasksSystem
        $TasksVsa = [Management.Automation.ValidateSetAttribute]::new([String[]]$AllTasks)

        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        $CategoryAttrs = [Collections.ObjectModel.Collection[Attribute]]::new()
        $CategoryParamAttr = [Management.Automation.ParameterAttribute]@{ ParameterSetName = 'Category'; Mandatory = $true }
        $CategoryAttrs.Add($CategoryParamAttr)
        $CategoryAttrs.Add($CategoryVsa)
        $CategoryParam = [Management.Automation.RuntimeDefinedParameter]::new('Category', [String[]], $CategoryAttrs)
        $RuntimeParams.Add('Category', $CategoryParam)

        $OptInAttrs = [Collections.ObjectModel.Collection[Attribute]]::new()
        $OptInParamAttr = [Management.Automation.ParameterAttribute]@{ ParameterSetName = 'OptIn'; Mandatory = $true }
        $OptInAttrs.Add($OptInParamAttr)
        $OptInAttrs.Add($TasksVsa)
        $OptInParam = [Management.Automation.RuntimeDefinedParameter]::new('IncludeTasks', [String[]], $OptInAttrs)
        $RuntimeParams.Add('IncludeTasks', $OptInParam)

        $OptOutAttrs = [Collections.ObjectModel.Collection[Attribute]]::new()
        $OptOutParamAttr = [Management.Automation.ParameterAttribute]@{ ParameterSetName = 'OptOut' }
        $OptOutAttrs.Add($OptOutParamAttr)
        $OptOutAttrs.Add($TasksVsa)
        $OptOutParam = [Management.Automation.RuntimeDefinedParameter]::new('ExcludeTasks', [String[]], $OptOutAttrs)
        $RuntimeParams.Add('ExcludeTasks', $OptOutParam)

        return $RuntimeParams
    }

    End {
        $WriteProgressParams = @{
            Id       = 0
            Activity = 'Updating all the things'
        }

        $Results = [PSCustomObject]@{
            Windows            = $null
            WSL                = $null
            Office             = $null
            VisualStudio       = $null
            PowerShell         = $null
            MicrosoftStore     = $null
            Edge               = $null
            Chrome             = $null
            WinGet             = $null
            Homebrew           = $null
            Scoop              = $null
            DotNetTools        = $null
            GoBinaries         = $null
            NodejsPackages     = $null
            Python             = $null
            PythonPipPackages  = $null
            PythonPipxPackages = $null
            QtComponents       = $null
            RubyGems           = $null
            RustToolchains     = $null
        }

        $Results.PSObject.TypeNames.Insert(0, 'DotFiles.Maintenance.UpdateAllTheThings')

        $Tasks = [Collections.Generic.List[String]]::new()

        switch ($PSCmdlet.ParameterSetName) {
            'Category' {
                foreach ($Category in $AllCategories) {
                    if ($PSBoundParameters['Category'] -contains $Category) {
                        $CategoryVar = "Tasks${Category}"
                        $CategoryTasks = Get-Variable -Name $CategoryVar -ValueOnly
                        foreach ($Task in $CategoryTasks) {
                            $Tasks.Add($Task)
                        }
                    }
                }
            }

            default {
                foreach ($Task in $AllTasks) {
                    if (($PSCmdlet.ParameterSetName -eq 'OptOut' -and $PSBoundParameters['ExcludeTasks'] -notcontains $Task) -or
                        ($PSCmdlet.ParameterSetName -eq 'OptIn' -and $PSBoundParameters['IncludeTasks'] -contains $Task)) {
                        $Tasks.Add($Task)
                    }
                }
            }
        }

        $TasksDone = 0
        $TasksTotal = $Tasks.Count
        Write-Verbose -Message "Running updates for: $($Tasks -join ', ')"

        if ($Tasks -contains 'Windows') {
            Write-Progress @WriteProgressParams -Status 'Windows' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.Windows = Update-Windows -ExcludeCategories @('Drivers', 'Driver Sets')
            } catch {
                $Results.Windows = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'WSL') {
            Write-Progress @WriteProgressParams -Status 'Windows Subsystem for Linux' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.WSL = Update-WSL
            } catch {
                $Results.WSL = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'Office') {
            Write-Progress @WriteProgressParams -Status 'Office' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.Office = Update-Office -ProgressParentId $WriteProgressParams['Id']
            } catch {
                $Results.Office = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'VisualStudio') {
            Write-Progress @WriteProgressParams -Status 'Visual Studio' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.VisualStudio = Update-VisualStudio -ProgressParentId $WriteProgressParams['Id']
            } catch {
                $Results.VisualStudio = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'PowerShell') {
            Write-Progress @WriteProgressParams -Status 'PowerShell' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.PowerShell = Update-PowerShell -ProgressParentId $WriteProgressParams['Id']
            } catch {
                $Results.PowerShell = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'MicrosoftStore') {
            Write-Progress @WriteProgressParams -Status 'Microsoft Store apps' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.MicrosoftStore = Update-MicrosoftStore
            } catch {
                $Results.MicrosoftStore = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'Edge') {
            Write-Progress @WriteProgressParams -Status 'Edge' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.Edge = Update-Edge -ProgressParentId $WriteProgressParams['Id']
            } catch {
                $Results.Edge = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'Chrome') {
            Write-Progress @WriteProgressParams -Status 'Chrome' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.Chrome = Update-Chrome -ProgressParentId $WriteProgressParams['Id']
            } catch {
                $Results.Chrome = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'WinGet') {
            Write-Progress @WriteProgressParams -Status 'WinGet' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.WinGet = Update-WinGet
            } catch {
                $Results.WinGet = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'Homebrew') {
            Write-Progress @WriteProgressParams -Status 'Homebrew' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.Homebrew = Update-Homebrew -ProgressParentId $WriteProgressParams['Id']
            } catch {
                $Results.Homebrew = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'Scoop') {
            Write-Progress @WriteProgressParams -Status 'Scoop' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.Scoop = Update-Scoop -ProgressParentId $WriteProgressParams['Id']
            } catch {
                $Results.Scoop = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'DotNetTools') {
            Write-Progress @WriteProgressParams -Status '.NET tools' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.DotNetTools = Update-DotNetTools -ProgressParentId $WriteProgressParams['Id']
            } catch {
                $Results.DotNetTools = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'GoBinaries') {
            Write-Progress @WriteProgressParams -Status 'Go binaries' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.GoBinaries = Update-GoBinaries
            } catch {
                $Results.GoBinaries = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'NodejsPackages') {
            Write-Progress @WriteProgressParams -Status 'Node.js packages' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.NodejsPackages = Update-NodejsPackages
            } catch {
                $Results.NodejsPackages = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'Python') {
            Write-Progress @WriteProgressParams -Status 'Python runtimes' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.Python = Update-Python
            } catch {
                $Results.Python = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'PythonPipPackages') {
            Write-Progress @WriteProgressParams -Status 'Python pip packages' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.PythonPipPackages = Update-PythonPipPackages
            } catch {
                $Results.PythonPipPackages = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'PythonPipxPackages') {
            Write-Progress @WriteProgressParams -Status 'Python pipx packages' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.PythonPipxPackages = Update-PythonPipxPackages
            } catch {
                $Results.PythonPipxPackages = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'QtComponents') {
            Write-Progress @WriteProgressParams -Status 'Qt components' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.QtComponents = Update-QtComponents
            } catch {
                $Results.QtComponents = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'RubyGems') {
            Write-Progress @WriteProgressParams -Status 'Ruby gems' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.RubyGems = Update-RubyGems
            } catch {
                $Results.RubyGems = $PSItem
            }

            $TasksDone++
        }

        if ($Tasks -contains 'RustToolchains') {
            Write-Progress @WriteProgressParams -Status 'Rust toolchains' -PercentComplete ($TasksDone / $TasksTotal * 100)

            try {
                $Results.RustToolchains = Update-RustToolchains
            } catch {
                $Results.RustToolchains = $PSItem
            }

            $TasksDone++
        }

        Write-Progress @WriteProgressParams -Completed
        return $Results
    }
}

Complete-DotFilesSection
