$null = Start-DotFilesSection -Type 'Functions' -Name 'Maintenance'

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Maintenance.format.ps1xml'))

# Retrieves a report containing:
# - Name and version for all vendored components
# - Path and last reviewed version for all configuration files
Function Global:Get-DotFilesLastUpdated {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    Param()

    try {
        Test-CommandAvailable -Name 'git', 'rg'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    try {
        Push-Location
        Set-Location -LiteralPath $DotFiles -ErrorAction 'Stop'

        # Exclude this file
        $RgGlobExcludeThis = "!$([IO.Path]::GetFileName($PSCommandPath))"

        # Exclude `.git` directory
        $RgGlobExcludeGit = '!.git/'

        $RgArgs = @(
            '--hidden'
            '--no-ignore-dot'
            '-g', $RgGlobExcludeGit
            '-g', $RgGlobExcludeThis
            'Last reviewed release: '
        )

        $LastReviewedReleases = & rg @RgArgs
        if ($LASTEXITCODE -ge 2) {
            $ExcMsg = "ripgrep exited with unexpected exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "rg $($RgArgs -join ' ')")
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $GitArgs = @('ls-files')
        $LastReviewedVersions = & git @GitArgs | Where-Object { $PSItem -match '[\\/]VERSION$' }
        if ($LASTEXITCODE -ne 0) {
            $ExcMsg = "Git exited with non-zero exit code: ${LASTEXITCODE}"
            $ErrExc = [Exception]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, "git $($GitArgs -join ' ')")
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $ComponentVersions = [Collections.Generic.List[PSCustomObject]]::new()

        foreach ($LastReviewedRelease in $LastReviewedReleases) {
            if ($LastReviewedRelease -notmatch '^(.+?):.*Last reviewed release: (.+)') {
                $ExcMsg = "Unexpected match returned by rg: ${LastReviewedRelease}"
                $ErrExc = [FormatException]::new($ExcMsg)
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

            if ([String]::IsNullOrWhiteSpace($Version)) {
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
Function Global:Clear-AllDevCaches {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(DefaultParameterSetName = 'OptOut', SupportsShouldProcess)]
    [OutputType([Void], [String[]])]
    Param()

    DynamicParam {
        $ValidTasks = [String[]]@('Docker', 'gem', 'Go', 'Gradle', 'Maven', 'npm', 'NuGet', 'pip')
        $TasksVsa = [Management.Automation.ValidateSetAttribute]::new($ValidTasks)

        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

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
            Id              = 0
            Activity        = 'Clearing caches for development environments & tooling'
            Status          = ''
            PercentComplete = 0
        }

        $Tasks = [Collections.Generic.List[String]]::new()

        foreach ($Task in $ValidTasks) {
            if (($PSCmdlet.ParameterSetName -eq 'OptOut' -and $PSBoundParameters['ExcludeTasks'] -notcontains $Task) -or
                ($PSCmdlet.ParameterSetName -eq 'OptIn' -and $PSBoundParameters['IncludeTasks'] -contains $Task)) {
                $Tasks.Add($Task)
            }
        }

        $TasksDone = 0
        $TasksTotal = $Tasks.Count
        Write-Verbose -Message "Clearing caches for: $($Tasks -join ', ')"

        if ($Tasks -contains 'Docker') {
            $WriteProgressParams['Status'] = 'Clearing Docker data'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            Write-Progress @WriteProgressParams

            try {
                Clear-DockerData -Force
            } catch { $PSCmdlet.WriteError($PSItem) }
        }

        if ($Tasks -contains 'gem') {
            $WriteProgressParams['Status'] = 'Clearing gem cache'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            Write-Progress @WriteProgressParams

            try {
                Clear-GemCache
            } catch { $PSCmdlet.WriteError($PSItem) }
        }

        if ($Tasks -contains 'Go') {
            $WriteProgressParams['Status'] = 'Clearing Go cache'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            Write-Progress @WriteProgressParams

            try {
                Clear-GoCache
            } catch { $PSCmdlet.WriteError($PSItem) }
        }

        if ($Tasks -contains 'Gradle') {
            $WriteProgressParams['Status'] = 'Clearing Gradle cache'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            Write-Progress @WriteProgressParams

            try {
                Clear-GradleCache
            } catch { $PSCmdlet.WriteError($PSItem) }
        }

        if ($Tasks -contains 'Maven') {
            $WriteProgressParams['Status'] = 'Clearing Maven cache'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            Write-Progress @WriteProgressParams

            try {
                Clear-MavenCache
            } catch { $PSCmdlet.WriteError($PSItem) }
        }

        if ($Tasks -contains 'npm') {
            $WriteProgressParams['Status'] = 'Clearing npm cache'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            Write-Progress @WriteProgressParams

            try {
                Clear-NpmCache
            } catch { $PSCmdlet.WriteError($PSItem) }
        }

        if ($Tasks -contains 'NuGet') {
            $WriteProgressParams['Status'] = 'Clearing NuGet cache'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            Write-Progress @WriteProgressParams

            try {
                Clear-NuGetCache
            } catch { $PSCmdlet.WriteError($PSItem) }
        }

        if ($Tasks -contains 'pip') {
            $WriteProgressParams['Status'] = 'Clearing pip cache'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            Write-Progress @WriteProgressParams

            try {
                Clear-PipCache
            } catch { $PSCmdlet.WriteError($PSItem) }
        }

        if ($Tasks.Count -ne 0) {
            Write-Progress @WriteProgressParams -Completed
        }
    }
}

# Update everything!
Function Global:Update-AllTheThings {
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

        $ValidTasks = $TasksApps + $TasksDevel + $TasksSystem
        $TasksVsa = [Management.Automation.ValidateSetAttribute]::new([String[]]$ValidTasks)

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
        Function Invoke-Task {
            [CmdletBinding()]
            [OutputType([PSObject])]
            Param(
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [Hashtable]$Progress,

                [Parameter(Mandatory)]
                [String]$Command,

                [ValidateNotNull()]
                [Hashtable]$Parameters = @{}
            )

            Write-Progress @Progress

            try {
                return & $Command @Parameters
            } catch {
                return $PSItem
            }
        }

        $WriteProgressParams = @{
            Id              = 0
            Activity        = 'Updating all the things'
            Status          = ''
            PercentComplete = 0
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
                foreach ($Task in $ValidTasks) {
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
            $WriteProgressParams['Status'] = 'Windows'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.Windows = Invoke-Task -Progress $WriteProgressParams -Command 'Update-Windows' -Parameters @{ ExcludeCategories = ('Drivers', 'Driver Sets') }
        }

        if ($Tasks -contains 'WSL') {
            $WriteProgressParams['Status'] = 'Windows Subsystem for Linux'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.WSL = Invoke-Task -Progress $WriteProgressParams -Command 'Update-WSL'
        }

        if ($Tasks -contains 'Office') {
            $WriteProgressParams['Status'] = 'Office'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.Office = Invoke-Task -Progress $WriteProgressParams -Command 'Update-Office' -Parameters @{ ProgressParentId = $WriteProgressParams['Id'] }
        }

        if ($Tasks -contains 'VisualStudio') {
            $WriteProgressParams['Status'] = 'Visual Studio'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.VisualStudio = Invoke-Task -Progress $WriteProgressParams -Command 'Update-VisualStudio' -Parameters @{ ProgressParentId = $WriteProgressParams['Id'] }
        }

        if ($Tasks -contains 'PowerShell') {
            $WriteProgressParams['Status'] = 'PowerShell'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.PowerShell = Invoke-Task -Progress $WriteProgressParams -Command 'Update-PowerShell' -Parameters @{ ProgressParentId = $WriteProgressParams['Id'] }
        }

        if ($Tasks -contains 'MicrosoftStore') {
            $WriteProgressParams['Status'] = 'Microsoft Store apps'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.MicrosoftStore = Invoke-Task -Progress $WriteProgressParams -Command 'Update-MicrosoftStore'
        }

        if ($Tasks -contains 'Edge') {
            $WriteProgressParams['Status'] = 'Edge'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.Edge = Invoke-Task -Progress $WriteProgressParams -Command 'Update-Edge' -Parameters @{ ProgressParentId = $WriteProgressParams['Id'] }
        }

        if ($Tasks -contains 'Chrome') {
            $WriteProgressParams['Status'] = 'Chrome'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.Chrome = Invoke-Task -Progress $WriteProgressParams -Command 'Update-Chrome' -Parameters @{ ProgressParentId = $WriteProgressParams['Id'] }
        }

        if ($Tasks -contains 'WinGet') {
            $WriteProgressParams['Status'] = 'WinGet'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.WinGet = Invoke-Task -Progress $WriteProgressParams -Command 'Update-WinGet'
        }

        if ($Tasks -contains 'Homebrew') {
            $WriteProgressParams['Status'] = 'Homebrew'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.Homebrew = Invoke-Task -Progress $WriteProgressParams -Command 'Update-Homebrew' -Parameters @{ ProgressParentId = $WriteProgressParams['Id'] }
        }

        if ($Tasks -contains 'Scoop') {
            $WriteProgressParams['Status'] = 'Scoop'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.Scoop = Invoke-Task -Progress $WriteProgressParams -Command 'Update-Scoop' -Parameters @{ ProgressParentId = $WriteProgressParams['Id'] }
        }

        if ($Tasks -contains 'DotNetTools') {
            $WriteProgressParams['Status'] = '.NET tools'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.DotNetTools = Invoke-Task -Progress $WriteProgressParams -Command 'Update-DotNetTools' -Parameters @{ ProgressParentId = $WriteProgressParams['Id'] }
        }

        if ($Tasks -contains 'GoBinaries') {
            $WriteProgressParams['Status'] = 'Go binaries'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.GoBinaries = Invoke-Task -Progress $WriteProgressParams -Command 'Update-GoBinaries'
        }

        if ($Tasks -contains 'NodejsPackages') {
            $WriteProgressParams['Status'] = 'Node.js packages'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.NodejsPackages = Invoke-Task -Progress $WriteProgressParams -Command 'Update-NodejsPackages'
        }

        if ($Tasks -contains 'Python') {
            $WriteProgressParams['Status'] = 'Python runtimes'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.Python = Invoke-Task -Progress $WriteProgressParams -Command 'Update-Python'
        }

        if ($Tasks -contains 'PythonPipPackages') {
            $WriteProgressParams['Status'] = 'Python pip packages'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.PythonPipPackages = Invoke-Task -Progress $WriteProgressParams -Command 'Update-PythonPipPackages'
        }

        if ($Tasks -contains 'PythonPipxPackages') {
            $WriteProgressParams['Status'] = 'Python pipx packages'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.PythonPipxPackages = Invoke-Task -Progress $WriteProgressParams -Command 'Update-PythonPipxPackages'
        }

        if ($Tasks -contains 'QtComponents') {
            $WriteProgressParams['Status'] = 'Qt components'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.QtComponents = Invoke-Task -Progress $WriteProgressParams -Command 'Update-QtComponents'
        }

        if ($Tasks -contains 'RubyGems') {
            $WriteProgressParams['Status'] = 'Ruby gems'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.RubyGems = Invoke-Task -Progress $WriteProgressParams -Command 'Update-RubyGems'
        }

        if ($Tasks -contains 'RustToolchains') {
            $WriteProgressParams['Status'] = 'Rust toolchains'
            $WriteProgressParams['PercentComplete'] = $TasksDone++ / $TasksTotal * 100
            $Results.RustToolchains = Invoke-Task -Progress $WriteProgressParams -Command 'Update-RustToolchains'
        }

        if ($Tasks.Count -ne 0) {
            Write-Progress @WriteProgressParams -Completed
        }

        return $Results
    }
}

Complete-DotFilesSection
