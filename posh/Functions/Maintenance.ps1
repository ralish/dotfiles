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
        'Docker',
        'gem',
        'Go',
        'Gradle',
        'Maven',
        'npm',
        'NuGet',
        'pip'
    )

    $Tasks = [Collections.ArrayList]::new()
    $TasksDone = 0
    $TasksTotal = 0

    foreach ($Task in $ValidTasks) {
        if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
            if ($ExcludeTasks -notcontains $Task) {
                $null = $Tasks.Add($Task)
                $TasksTotal++
            }
        } else {
            if ($IncludeTasks -contains $Task) {
                $null = $Tasks.Add($Task)
                $TasksTotal++
            }
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
    Param(
        [Parameter(ParameterSetName = 'OptOut')]
        [ValidateSet(
            'Windows',
            'Office',
            'VisualStudio',
            'PowerShell',
            'ModernApps',
            'Scoop',
            'DotNetTools',
            'NodejsPackages',
            'PythonPackages',
            'RubyGems'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName = 'OptIn', Mandatory)]
        [ValidateSet(
            'Windows',
            'Office',
            'VisualStudio',
            'PowerShell',
            'ModernApps',
            'Scoop',
            'DotNetTools',
            'NodejsPackages',
            'PythonPackages',
            'RubyGems'
        )]
        [String[]]$IncludeTasks
    )

    $Tasks = @{
        Windows        = $null
        Office         = $null
        VisualStudio   = $null
        PowerShell     = $null
        ModernApps     = $null
        Scoop          = $null
        DotNetTools    = $null
        NodejsPackages = $null
        PythonPackages = $null
        RubyGems       = $null
    }

    $TasksDone = 0
    $TasksTotal = 0

    foreach ($Task in @($Tasks.Keys)) {
        if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
            if ($ExcludeTasks -contains $Task) {
                $Tasks[$Task] = $false
            } else {
                $Tasks[$Task] = $true
                $TasksTotal++
            }
        } else {
            if ($IncludeTasks -contains $Task) {
                $Tasks[$Task] = $true
                $TasksTotal++
            } else {
                $Tasks[$Task] = $false
            }
        }
    }

    if ($Tasks['Windows'] -or $Tasks['Office'] -or $Tasks['VisualStudio'] -or $Tasks['ModernApps']) {
        if (!(Test-IsAdministrator)) {
            throw 'You must have administrator privileges to perform Windows, Office, Visual Studio, or Modern Apps updates.'
        }
    }

    $Results = [PSCustomObject]@{
        Windows        = $null
        Office         = $null
        VisualStudio   = $null
        PowerShell     = $null
        ModernApps     = $null
        Scoop          = $null
        DotNetTools    = $null
        NodejsPackages = $null
        PythonPackages = $null
        RubyGems       = $null
    }

    $WriteProgressParams = @{
        Id       = 0
        Activity = 'Updating all the things'
    }

    if ($Tasks['Windows']) {
        Write-Progress @WriteProgressParams -Status 'Updating Windows' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.Windows = Update-Windows -AcceptAll -PassThru
        $TasksDone++
    }

    if ($Tasks['Office']) {
        Write-Progress @WriteProgressParams -Status 'Updating Office' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.Office = Update-Office -PassThru -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['VisualStudio']) {
        Write-Progress @WriteProgressParams -Status 'Updating Visual Studio' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.VisualStudio = Update-VisualStudio -PassThru -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['PowerShell']) {
        Write-Progress @WriteProgressParams -Status 'Updating PowerShell' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.PowerShell = Update-PowerShell -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['ModernApps']) {
        Write-Progress @WriteProgressParams -Status 'Updating Microsoft Store apps' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.ModernApps = Update-ModernApps
        $TasksDone++
    }

    if ($Tasks['Scoop']) {
        Write-Progress @WriteProgressParams -Status 'Updating Scoop apps' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.Scoop = Update-Scoop -CaptureOutput -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['DotNetTools']) {
        Write-Progress @WriteProgressParams -Status 'Updating .NET tools' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.DotNetTools = Update-DotNetTools -ProgressParentId $WriteProgressParams['Id']
        $TasksDone++
    }

    if ($Tasks['NodejsPackages']) {
        Write-Progress @WriteProgressParams -Status 'Updating Node.js packages' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.NodejsPackages = Update-NodejsPackages
        $TasksDone++
    }

    if ($Tasks['PythonPackages']) {
        Write-Progress @WriteProgressParams -Status 'Updating Python packages' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.PythonPackages = Update-PythonPackages
        $TasksDone++
    }

    if ($Tasks['RubyGems']) {
        Write-Progress @WriteProgressParams -Status 'Updating Ruby gems' -PercentComplete ($TasksDone / $TasksTotal * 100)
        $Results.RubyGems = Update-RubyGems
        $TasksDone++
    }

    Write-Progress @WriteProgressParams -Completed

    return $Results
}
