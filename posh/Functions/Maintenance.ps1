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
    [CmdletBinding(DefaultParameterSetName = 'OptOut')]
    [OutputType([PSCustomObject])]
    Param()

    DynamicParam {
        $ValidTasks = @(
            'PowerShell'
            'DotNetTools'
            'NodejsPackages'
            'PythonPackages'
            'QtComponents'
            'RubyGems'
            'RustToolchains'
        )

        if (Test-IsWindows) {
            $ValidTasks += @(
                'Windows'
                'WSL'
                'Office'
                'VisualStudio'
                'MicrosoftStore'
                'Scoop'
            )
        } else {
            $ValidTasks += 'Homebrew'
        }

        $ValidateSetAttr = [Management.Automation.ValidateSetAttribute]::new([String[]]$ValidTasks)

        $OptOutParamAttr = [Management.Automation.ParameterAttribute]@{
            ParameterSetName = 'OptOut'
        }

        $OptInParamAttr = [Management.Automation.ParameterAttribute]@{
            ParameterSetName = 'OptIn'
            Mandatory        = $true
        }

        $OptOutAttrCollection = [Collections.ObjectModel.Collection[Attribute]]::new()
        $OptOutAttrCollection.Add($ValidateSetAttr)
        $OptOutAttrCollection.Add($OptOutParamAttr)

        $OptInAttrCollection = [Collections.ObjectModel.Collection[Attribute]]::new()
        $OptInAttrCollection.Add($ValidateSetAttr)
        $OptInAttrCollection.Add($OptInParamAttr)

        $OptOutParam = [Management.Automation.RuntimeDefinedParameter]::new(
            'ExcludeTasks', [String[]], $OptOutAttrCollection
        )

        $OptInParam = [Management.Automation.RuntimeDefinedParameter]::new(
            'IncludeTasks', [String[]], $OptInAttrCollection
        )

        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
        $RuntimeParams.Add('ExcludeTasks', $OptOutParam)
        $RuntimeParams.Add('IncludeTasks', $OptInParam)

        return $RuntimeParams
    }

    End {
        $Tasks = [Collections.Generic.List[String]]::new()
        $TasksDone = 0
        $TasksTotal = 0
        $Results = [PSCustomObject]@{}

        foreach ($Task in $ValidTasks) {
            if (($PSCmdlet.ParameterSetName -eq 'OptOut' -and $PSBoundParameters['ExcludeTasks'] -notcontains $Task) -or
                ($PSCmdlet.ParameterSetName -eq 'OptIn' -and $PSBoundParameters['IncludeTasks'] -contains $Task)) {
                $Tasks.Add($Task)
                $TasksTotal++
                $Results | Add-Member -Name $Task -MemberType NoteProperty -Value $null
            }
        }

        if (Test-IsWindows) {
            if ($Tasks -contains 'Windows' -or $Tasks -contains 'Office' -or $Tasks -contains 'VisualStudio' -or $Tasks -contains 'MicrosoftStore') {
                if (!(Test-IsAdministrator)) {
                    throw 'You must have administrator privileges to perform Windows, Office, Visual Studio, or Microsoft Store updates.'
                }
            }
        }

        $WriteProgressParams = @{
            Id       = 0
            Activity = 'Updating all the things'
        }

        if ($Tasks -contains 'Windows') {
            Write-Progress @WriteProgressParams -Status 'Windows' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.Windows = Update-Windows -AcceptAll
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
