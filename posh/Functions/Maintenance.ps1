Start-DotFilesSection -Type 'Functions' -Name 'Maintenance'

# Clear caches used by development environments & tooling
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

    Write-Verbose -Message ('Clearing caches for: {0}' -f ($Tasks -join ', '))

    $WriteProgressParams = @{
        Id       = 0
        Activity = 'Clearing caches for development environments & tooling'
    }

    if ($Tasks -contains 'Docker') {
        Write-Progress @WriteProgressParams -Status 'Clearing Docker cache' -PercentComplete ($TasksDone / $TasksTotal * 100)
        Clear-DockerCache
        $TasksDone++
    }

    if ($Tasks -contains 'gem') {
        Write-Progress @WriteProgressParams -Status 'Clearing gem cache' -PercentComplete ($TasksDone / $TasksTotal * 100)
        Clear-GemCache
        $TasksDone++
    }

    if ($Tasks -contains 'Go') {
        Write-Progress @WriteProgressParams -Status 'Clearing Go cache' -PercentComplete ($TasksDone / $TasksTotal * 100)
        Clear-GoCache
        $TasksDone++
    }

    if ($Tasks -contains 'Gradle') {
        Write-Progress @WriteProgressParams -Status 'Clearing Gradle cache' -PercentComplete ($TasksDone / $TasksTotal * 100)
        Clear-GradleCache
        $TasksDone++
    }

    if ($Tasks -contains 'Maven') {
        Write-Progress @WriteProgressParams -Status 'Clearing Maven cache' -PercentComplete ($TasksDone / $TasksTotal * 100)
        Clear-MavenCache
        $TasksDone++
    }

    if ($Tasks -contains 'npm') {
        Write-Progress @WriteProgressParams -Status 'Clearing npm cache' -PercentComplete ($TasksDone / $TasksTotal * 100)
        Clear-NpmCache
        $TasksDone++
    }

    if ($Tasks -contains 'NuGet') {
        Write-Progress @WriteProgressParams -Status 'Clearing NuGet cache' -PercentComplete ($TasksDone / $TasksTotal * 100)
        Clear-NuGetCache
        $TasksDone++
    }

    if ($Tasks -contains 'pip') {
        Write-Progress @WriteProgressParams -Status 'Clearing pip cache' -PercentComplete ($TasksDone / $TasksTotal * 100)
        Clear-PipCache
        $TasksDone++
    }
}

# Update everything!
Function Update-AllTheThings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(DefaultParameterSetName = 'OptOut', SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    Param()

    DynamicParam {
        $TasksApps = @('PowerShell')
        $TasksDevel = @('DotNetTools', 'GoExecutables', 'NodejsPackages', 'PythonPackages', 'RubyGems', 'RustToolchains')
        $TasksSystem = @()

        if (Test-IsWindows) {
            $TasksApps += @('MicrosoftStore', 'Office', 'Scoop', 'VisualStudio')
            $TasksDevel += @('QtComponents')
            $TasksSystem += @('Windows', 'WSL')
        } else {
            $TasksApps += @('Homebrew')
        }

        $AllTasks = $TasksApps + $TasksDevel + $TasksSystem
        $TasksVsa = [Management.Automation.ValidateSetAttribute]::new([String[]]$AllTasks)

        $AllCategories = @('Apps', 'Devel', 'System')
        $CategoriesVsa = [Management.Automation.ValidateSetAttribute]::new([String[]]$AllCategories)

        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()

        # Category parameter set
        $CategoryParamAttr = [Management.Automation.ParameterAttribute]@{
            ParameterSetName = 'Category'
            Mandatory        = $true
        }

        $CategoryAttrs = [Collections.ObjectModel.Collection[Attribute]]::new()
        $CategoryAttrs.Add($CategoriesVsa)
        $CategoryAttrs.Add($CategoryParamAttr)

        $CategoryParam = [Management.Automation.RuntimeDefinedParameter]::new(
            'Category', [String[]], $CategoryAttrs
        )

        $RuntimeParams.Add('Category', $CategoryParam)

        # OptIn parameter set
        $OptInParamAttr = [Management.Automation.ParameterAttribute]@{
            ParameterSetName = 'OptIn'
            Mandatory        = $true
        }

        $OptInAttrs = [Collections.ObjectModel.Collection[Attribute]]::new()
        $OptInAttrs.Add($TasksVsa)
        $OptInAttrs.Add($OptInParamAttr)

        $OptInParam = [Management.Automation.RuntimeDefinedParameter]::new(
            'IncludeTasks', [String[]], $OptInAttrs
        )

        $RuntimeParams.Add('IncludeTasks', $OptInParam)

        # OptOut parameter set
        $OptOutParamAttr = [Management.Automation.ParameterAttribute]@{
            ParameterSetName = 'OptOut'
        }

        $OptOutAttrs = [Collections.ObjectModel.Collection[Attribute]]::new()
        $OptOutAttrs.Add($TasksVsa)
        $OptOutAttrs.Add($OptOutParamAttr)

        $OptOutParam = [Management.Automation.RuntimeDefinedParameter]::new(
            'ExcludeTasks', [String[]], $OptOutAttrs
        )

        $RuntimeParams.Add('ExcludeTasks', $OptOutParam)

        return $RuntimeParams
    }

    End {
        $Results = [PSCustomObject]@{}
        $Tasks = [Collections.Generic.List[String]]::new()
        $TasksDone = 0
        $TasksTotal = 0

        if ($PSCmdlet.ParameterSetName -eq 'Category') {
            foreach ($Category in $AllCategories) {
                if ($PSBoundParameters['Category'] -contains $Category) {
                    $CategoryVar = 'Tasks{0}' -f $Category
                    $CategoryTasks = Get-Variable -Name $CategoryVar -ValueOnly
                    foreach ($Task in $CategoryTasks) {
                        $Tasks.Add($Task)
                    }
                }
            }
        } else {
            foreach ($Task in $AllTasks) {
                if (($PSCmdlet.ParameterSetName -eq 'OptOut' -and $PSBoundParameters['ExcludeTasks'] -notcontains $Task) -or
                    ($PSCmdlet.ParameterSetName -eq 'OptIn' -and $PSBoundParameters['IncludeTasks'] -contains $Task)) {
                    $Tasks.Add($Task)
                }
            }
        }

        $TasksTotal = $Tasks.Count
        foreach ($Task in $Tasks) {
            $Results | Add-Member -Name $Task -MemberType NoteProperty -Value $null
        }

        if ($Tasks -contains 'Windows' -or $Tasks -contains 'Office' -or $Tasks -contains 'VisualStudio' -or $Tasks -contains 'MicrosoftStore') {
            $IsAdministrator = Test-IsAdministrator
            if (!$IsAdministrator -and !$WhatIfPreference) {
                throw 'You must have administrator privileges to perform Windows, Office, Visual Studio, or Microsoft Store updates.'
            }
        }

        Write-Verbose -Message ('Running updates for: {0}' -f ($Tasks -join ', '))

        $WriteProgressParams = @{
            Id       = 0
            Activity = 'Updating all the things'
        }

        if ($Tasks -contains 'Windows') {
            Write-Progress @WriteProgressParams -Status 'Windows' -PercentComplete ($TasksDone / $TasksTotal * 100)

            if ($IsAdministrator) {
                $Results.Windows = Update-Windows -AcceptAll
            } else {
                # Only for -WhatIf without administrator privileges
                Write-Warning -Message 'Retrieving available Windows Updates requires administrator privileges.'
            }

            $TasksDone++
        }

        if ($Tasks -contains 'WSL') {
            Write-Progress @WriteProgressParams -Status 'Windows Subsystem for Linux' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.WSL = Update-WSL
            $TasksDone++
        }

        if ($Tasks -contains 'Office') {
            Write-Progress @WriteProgressParams -Status 'Office' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.Office = Update-Office -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'VisualStudio') {
            Write-Progress @WriteProgressParams -Status 'Visual Studio' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.VisualStudio = Update-VisualStudio -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'PowerShell') {
            Write-Progress @WriteProgressParams -Status 'PowerShell' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.PowerShell = Update-PowerShell -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'MicrosoftStore') {
            Write-Progress @WriteProgressParams -Status 'Microsoft Store' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.MicrosoftStore = Update-MicrosoftStore
            $TasksDone++
        }

        if ($Tasks -contains 'Homebrew') {
            Write-Progress @WriteProgressParams -Status 'Homebrew' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.Homebrew = Update-Homebrew -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'Scoop') {
            Write-Progress @WriteProgressParams -Status 'Scoop' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.Scoop = Update-Scoop -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'DotNetTools') {
            Write-Progress @WriteProgressParams -Status '.NET tools' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.DotNetTools = Update-DotNetTools -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'GoExecutables') {
            Write-Progress @WriteProgressParams -Status 'Go executables' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.GoExecutables = Update-GoExecutables
            $TasksDone++
        }

        if ($Tasks -contains 'NodejsPackages') {
            Write-Progress @WriteProgressParams -Status 'Node.js packages' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.NodejsPackages = Update-NodejsPackages
            $TasksDone++
        }

        if ($Tasks -contains 'PythonPackages') {
            Write-Progress @WriteProgressParams -Status 'Python packages' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.PythonPackages = Update-PythonPackages
            $TasksDone++
        }

        if ($Tasks -contains 'QtComponents') {
            Write-Progress @WriteProgressParams -Status 'Qt components' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.QtComponents = Update-QtComponents
            $TasksDone++
        }

        if ($Tasks -contains 'RubyGems') {
            Write-Progress @WriteProgressParams -Status 'Ruby gems' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.RubyGems = Update-RubyGems
            $TasksDone++
        }

        if ($Tasks -contains 'RustToolchains') {
            Write-Progress @WriteProgressParams -Status 'Rust toolchains' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.RustToolchains = Update-RustToolchains
            $TasksDone++
        }

        Write-Progress @WriteProgressParams -Completed

        return $Results
    }
}

Complete-DotFilesSection
