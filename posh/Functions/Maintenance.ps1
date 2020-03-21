Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing maintenance functions ...')

# Update everything!
Function Update-AllTheThings {
    [CmdletBinding(DefaultParameterSetName='OptOut')]
    Param(
        [Parameter(ParameterSetName='OptOut')]
        [ValidateSet(
            'Windows',
            'Office',
            'VisualStudio',
            'PowerShell',
            'ModernApps',
            'Scoop',
            'NodejsPackages',
            'PythonPackages',
            'RubyGems'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName='OptIn', Mandatory)]
        [ValidateSet(
            'Windows',
            'Office',
            'VisualStudio',
            'PowerShell',
            'ModernApps',
            'Scoop',
            'NodejsPackages',
            'PythonPackages',
            'RubyGems'
        )]
        [String[]]$IncludeTasks
    )

    $Tasks = @{
        Windows         = $null
        Office          = $null
        VisualStudio    = $null
        PowerShell      = $null
        ModernApps      = $null
        Scoop           = $null
        NodejsPackages  = $null
        PythonPackages  = $null
        RubyGems        = $null
    }

    foreach ($Task in @($Tasks.Keys)) {
        if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
            if ($ExcludeTasks -contains $Task) {
                $Tasks[$Task] = $false
            } else {
                $Tasks[$Task] = $true
            }
        } else {
            if ($IncludeTasks -contains $Task) {
                $Tasks[$Task] = $true
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
        Windows         = $null
        Office          = $null
        VisualStudio    = $null
        PowerShell      = $null
        ModernApps      = $null
        Scoop           = $null
        NodejsPackages  = $null
        PythonPackages  = $null
        RubyGems        = $null
    }

    if ($Tasks['Windows']) {
        $Results.Windows = Update-Windows
    }

    if ($Tasks['Office']) {
        $Results.Office = Update-Office
    }

    if ($Tasks['VisualStudio']) {
        $Results.VisualStudio = Update-VisualStudio
    }

    if ($Tasks['PowerShell']) {
        $Results.PowerShell = Update-PowerShell
    }

    if ($Tasks['ModernApps']) {
        $Results.ModernApps = Update-ModernApps
    }

    if ($Tasks['Scoop']) {
        $Results.Scoop = Update-Scoop
    }

    if ($Tasks['NodejsPackages']) {
        $Results.NodejsPackages = Update-NodejsPackages
    }

    if ($Tasks['PythonPackages']) {
        $Results.PythonPackages = Update-PythonPackages
    }

    if ($Tasks['RubyGems']) {
        $Results.RubyGems = Update-RubyGems
    }

    return $Results
}

# Update Ruby packages
Function Update-RubyGems {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    try {
        $null = Get-Command -Name gem -ErrorAction Stop
    } catch {
        Write-Error -Message 'Unable to update Ruby gems as gem command not found.'
        return
    }

    $UpdateArgs = @('update', '--no-document')
    if (!$PSCmdlet.ShouldProcess('Ruby gems', 'Update')) {
        $UpdateArgs += '--explain'
    }

    Write-Host -ForegroundColor Green -Object 'Enumerating Ruby gems ...'
    $Packages = [Collections.ArrayList]@()
    $PackageRegex = [Regex]::new('\(default: \S+\)')
    & gem list --local --no-details | ForEach-Object {
        if (!$PackageRegex.Match($_).Success) {
            $null = $Packages.Add($_.Split(' ')[0])
        }
    }

    & gem @UpdateArgs @Packages
}

# Update Modern Apps (Microsoft Store)
Function Update-ModernApps {
    [CmdletBinding()]
    Param()

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Modern Apps updates.'
    }

    $Namespace = 'root\CIMv2\mdm\dmmap'
    $Class = 'MDM_EnterpriseModernAppManagement_AppManagement01'
    $Method = 'UpdateScanMethod'

    $Session = New-CimSession
    $Instance = Get-CimInstance -Namespace $Namespace -ClassName $Class
    $Result = $Session.InvokeMethod($Namespace, $Instance, $Method, $null)

    return $Result
}

# Update Node.js packages
Function Update-NodejsPackages {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    try {
        $null = Get-Command -Name npm -ErrorAction Stop
    } catch {
        Write-Error -Message 'Unable to update Node.js packages as npm command not found.'
        return
    }

    $UpdateArgs = @('update', '--global')
    if ($PSCmdlet.ShouldProcess('Node.js packages', 'Update')) {
        $UpdateArgs += '--dry-run'
    }

    Write-Host -ForegroundColor Green -Object 'Updating Node.js npm ...'
    & npm @UpdateArgs npm

    Write-Host -ForegroundColor Green -Object 'Updating Node.js packages ...'
    & npm @UpdateArgs
}

# Update Microsoft Office (Click-to-Run only)
Function Update-Office {
    [CmdletBinding()]
    Param()

    # The new Update Now feature for Office 2013 Click-to-Run for Office365 and its associated command-line and switches
    # https://blogs.technet.microsoft.com/odsupport/2014/03/03/the-new-update-now-feature-for-office-2013-click-to-run-for-office365-and-its-associated-command-line-and-switches/

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Office updates.'
    }

    $OfficeC2RClient = Join-Path -Path $env:ProgramFiles -ChildPath 'Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe'
    if (!(Test-Path -Path $OfficeC2RClient -PathType Leaf)) {
        Write-Warning -Message 'Unable to install Office updates as Click-to-Run client not found.'
        return $false
    }

    Write-Host -ForegroundColor Green -Object 'Installing Office updates ...'
    Start-Process -FilePath $OfficeC2RClient -ArgumentList @('/update', 'user', 'updatepromptuser=True') -NoNewWindow -Wait
    Start-Sleep -Seconds 3

    do {
        $OfficeRegPath = 'HKLM:\Software\Microsoft\Office\ClickToRun'
        $OfficeRegKey = Get-Item -Path $OfficeRegPath

        $ExecutingScenario = $OfficeRegKey.GetValue('ExecutingScenario')
        $ExecutingScenarioPrevious = [String]::Empty
        if ($ExecutingScenario) {
            if ($ExecutingScenario -ne $ExecutingScenarioPrevious) {
                $ExecutingScenarioPrevious = $ExecutingScenario
                Write-Verbose -Message ('Office update currently running scenario: {0}' -f $ExecutingScenario)
            }
        } else {
            $LastScenario = $OfficeRegKey.GetValue('LastScenario')
            $LastScenarioResult = $OfficeRegKey.GetValue('LastScenarioResult')
            break
        }

        $TasksRegPath = Join-Path -Path $OfficeRegPath -ChildPath ('Scenario\{0}\TasksState' -f $ExecutingScenario)
        $TasksRegKey = Get-Item -Path $TasksRegPath

        foreach ($Task in $TasksRegKey.GetValueNames()) {
            $TaskName = $Task.Split(':')[0]
            $TaskStatus = $TasksRegKey.GetValue($Task)

            if ($TaskStatus -eq 'TASKSTATE_FAILED') {
                Write-Warning -Message ('Office update task failed in {0} scenario: {1}' -f $ExecutingScenario, $TaskName)
            }

            if ($TaskStatus -eq 'TASKSTATE_CANCELLED') {
                Write-Warning -Message ('Office update task cancelled in {0} scenario: {1}' -f $ExecutingScenario, $TaskName)
            }
        }

        Start-Sleep -Seconds 5
    } while ($true)

    Write-Verbose -Message ('Office update finished {0} scenario with result: {1}' -f $LastScenario, $LastScenarioResult)
    if ($LastScenarioResult -ne 'Success') {
        return $false
    }

    return $true
}

# Update Python packages
Function Update-PythonPackages {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    try {
        $null = Get-Command -Name pipdeptree -ErrorAction Stop
    } catch {
        Write-Error -Message 'Unable to update Python packages as pipdeptree command not found.'
        return
    }

    if ($PSCmdlet.ShouldProcess('Python packages', 'Update')) {
        $UpdateArgs = @('install', '--no-python-version-warning', '--upgrade')
    }

    if ($UpdateArgs) {
        Write-Host -ForegroundColor Green -Object 'Updating Python pip ...'
        & python -m pip @UpdateArgs pip
    }

    Write-Host -ForegroundColor Green -Object 'Enumerating Python packages ...'
    $Packages = [Collections.ArrayList]@()
    $PackageRegex = [Regex]::new('^\S+==')
    & pipdeptree | ForEach-Object {
        if ($PackageRegex.Match($_).Success) {
            $null = $Packages.Add($_.Split('=')[0])
        }
    }

    if ($UpdateArgs) {
        Write-Host -ForegroundColor Green -Object 'Updating Python packages ...'
        & pip @UpdateArgs --upgrade-strategy eager @Packages
    } else {
        'Packages to update:'
        $Packages -join [Environment]::NewLine
    }
}

# Update PowerShell modules & built-in help
Function Update-PowerShell {
    [CmdletBinding()]
    Param()

    if (Get-Module -Name PowerShellGet -ListAvailable) {
        Write-Host -ForegroundColor Green -Object 'Updating PowerShell modules ...'
        Update-Module
    } else {
        Write-Warning -Message 'Unable to update PowerShell modules as PowerShellGet module not available.'
    }

    if (Get-Command -Name Uninstall-ObsoleteModule) {
        Write-Host -ForegroundColor Green -Object 'Uninstalling obsolete PowerShell modules ...'
        Uninstall-ObsoleteModule
    } else {
        Write-Warning -Message 'Unable to uninstall obsolete PowerShell modules as Uninstall-ObsoleteModule command not available.'
    }

    Write-Host -ForegroundColor Green -Object 'Updating PowerShell help ...'
    Update-Help -Force

    return $true
}

# Update Scoop & installed apps
Function Update-Scoop {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
    [CmdletBinding()]
    Param()

    if (!(Get-Command -Name scoop)) {
        Write-Warning -Message 'Unable to install Scoop updates as scoop command not found.'
        return $false
    }
    Write-Host -ForegroundColor Green -Object 'Updating Scoop ...'
    & scoop update --quiet

    Write-Host -ForegroundColor Green -Object 'Updating Scoop apps ...'
    & scoop update * --quiet

    return $true
}

# Update Microsoft Visual Studio
Function Update-VisualStudio {
    [CmdletBinding()]
    Param()

    # Use command-line parameters to install Visual Studio 2017
    # https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2017

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Visual Studio updates.'
    }

    $VsInstaller = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Visual Studio\Installer\vs_installer.exe'
    if (!(Test-Path -Path $VsInstaller -PathType Leaf)) {
        Write-Warning -Message 'Unable to install Visual Studio updates as VS Installer not found.'
        return $false
    }

    Write-Host -ForegroundColor Green -Object 'Updating Visual Studio Installer ...'
    Start-Process -FilePath $VsInstaller -ArgumentList @('--update', '--passive', '--norestart', '--wait') -NoNewWindow -Wait

    Write-Host -ForegroundColor Green -Object 'Updating Visual Studio ...'
    Start-Process -FilePath $VsInstaller -ArgumentList @('update', '--passive', '--norestart', '--wait') -NoNewWindow -Wait

    return $true
}

# Update Microsoft Windows
Function Update-Windows {
    [CmdletBinding()]
    Param()

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform Windows updates.'
    }

    if (!(Get-Module -Name PSWindowsUpdate -ListAvailable)) {
        Write-Warning -Message 'Unable to install Windows updates as PSWindowsUpdate module not available.'
        return $false
    }

    Write-Host -ForegroundColor Green -Object 'Installing Windows updates ...'
    $Results = Install-WindowsUpdate -IgnoreReboot -NotTitle Silverlight
    if ($Results) {
        return $Results
    }

    return $true
}
