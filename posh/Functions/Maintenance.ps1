if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing maintenance functions ...')

# Clear caches used by development environments & tooling
Function Clear-AllDevCaches {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(DefaultParameterSetName = 'OptOut', SupportsShouldProcess)]
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
    Param()

    DynamicParam {
        $ValidTasks = @(
            'PowerShell'
            'DotNetTools'
            'NodejsPackages'
            'PythonPackages'
            'RubyGems'
        )

        if (Test-IsWindows) {
            $ValidTasks += @(
                'Windows'
                'Office'
                'VisualStudio'
                'ModernApps'
                'Scoop'
            )
        }

        $AttrValidateSet = [Management.Automation.ValidateSetAttribute]::new([String[]]$ValidTasks)

        $AttrParameterOptOut = [Management.Automation.ParameterAttribute]@{
            ParameterSetName = 'OptOut'
        }

        $AttrParameterOptIn = [Management.Automation.ParameterAttribute]@{
            ParameterSetName = 'OptIn'
            Mandatory        = $true
        }

        $AttrCollectionOptOut = [Collections.ObjectModel.Collection[Attribute]]::new()
        $AttrCollectionOptOut.Add($AttrParameterOptOut)
        $AttrCollectionOptOut.Add($AttrValidateSet)

        $AttrCollectionOptIn = [Collections.ObjectModel.Collection[Attribute]]::new()
        $AttrCollectionOptIn.Add($AttrParameterOptIn)
        $AttrCollectionOptIn.Add($AttrValidateSet)

        $ParamOptOut = [Management.Automation.RuntimeDefinedParameter]::new(
            'ExcludeTasks', [String[]], $AttrCollectionOptOut
        )

        $ParamOptIn = [Management.Automation.RuntimeDefinedParameter]::new(
            'IncludeTasks', [String[]], $AttrCollectionOptIn
        )

        $ParamDict = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
        $ParamDict.Add('ExcludeTasks', $ParamOptOut)
        $ParamDict.Add('IncludeTasks', $ParamOptIn)

        return $ParamDict
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
            if ($Tasks -contains 'Windows' -or $Tasks -contains 'Office' -or $Tasks -contains 'VisualStudio' -or $Tasks -contains 'ModernApps') {
                if (!(Test-IsAdministrator)) {
                    throw 'You must have administrator privileges to perform Windows, Office, Visual Studio, or Modern Apps updates.'
                }
            }
        }

        $WriteProgressParams = @{
            Id       = 0
            Activity = 'Updating all the things'
        }

        if ($Tasks -contains 'Windows') {
            Write-Progress @WriteProgressParams -Status 'Updating Windows' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.Windows = Update-Windows -AcceptAll
            $TasksDone++
        }

        if ($Tasks -contains 'Office') {
            Write-Progress @WriteProgressParams -Status 'Updating Office' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.Office = Update-Office -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'VisualStudio') {
            Write-Progress @WriteProgressParams -Status 'Updating Visual Studio' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.VisualStudio = Update-VisualStudio -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'PowerShell') {
            Write-Progress @WriteProgressParams -Status 'Updating PowerShell' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.PowerShell = Update-PowerShell -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'ModernApps') {
            Write-Progress @WriteProgressParams -Status 'Updating Microsoft Store apps' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.ModernApps = Update-ModernApps
            $TasksDone++
        }

        if ($Tasks -contains 'Scoop') {
            Write-Progress @WriteProgressParams -Status 'Updating Scoop apps' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.Scoop = Update-Scoop -CaptureOutput -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'DotNetTools') {
            Write-Progress @WriteProgressParams -Status 'Updating .NET tools' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.DotNetTools = Update-DotNetTools -ProgressParentId $WriteProgressParams['Id']
            $TasksDone++
        }

        if ($Tasks -contains 'NodejsPackages') {
            Write-Progress @WriteProgressParams -Status 'Updating Node.js packages' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.NodejsPackages = Update-NodejsPackages
            $TasksDone++
        }

        if ($Tasks -contains 'PythonPackages') {
            Write-Progress @WriteProgressParams -Status 'Updating Python packages' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.PythonPackages = Update-PythonPackages
            $TasksDone++
        }

        if ($Tasks -contains 'RubyGems') {
            Write-Progress @WriteProgressParams -Status 'Updating Ruby gems' -PercentComplete ($TasksDone / $TasksTotal * 100)
            $Results.RubyGems = Update-RubyGems
            $TasksDone++
        }

        Write-Progress @WriteProgressParams -Completed

        return $Results
    }
}
