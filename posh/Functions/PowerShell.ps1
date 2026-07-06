$null = Start-DotFilesSection -Type 'Functions' -Name 'PowerShell'

#region .NET

# Retrieve all type accelerators
Function Global:Get-TypeAccelerator {
    [CmdletBinding()]
    [OutputType([Collections.Generic.Dictionary[String, Type]])]
    Param()

    [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::get_Get()
}

# Retrieve the constructors for a type
Function Global:Get-TypeConstructor {
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

            if ($ConstructorParams.Count -ne 0) {
                $FormattedConstructorParams = @($ConstructorParams | ForEach-Object { $PSItem.ToString() })
                $FormattedParams = "$($Type.FullName)($($FormattedConstructorParams -join ', '))"
            } else {
                $FormattedParams = "$($Type.FullName)()"
            }

            [PSCustomObject]@{
                Constructor = $FormattedParams
            }
        }
    }
}

# Retrieve the methods for a type
Function Global:Get-TypeMethod {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Type]$Type
    )

    Process {
        $Methods = $Type.GetMethods() | Sort-Object -Property 'Name'
        foreach ($Method in $Methods) {
            $MethodParams = $Method.GetParameters()

            if ($MethodParams.Count -ne 0) {
                $FormattedMethodParams = @($MethodParams | ForEach-Object { $PSItem.ToString() })
                $FormattedParams = '({0})' -f $FormattedMethodParams -join ', '
            } else {
                $FormattedParams = '()'
            }

            [PSCustomObject]@{
                Method     = $Method.Name
                Parameters = $FormattedParams
            }
        }
    }
}

#endregion

#region Internals

# Retrieve custom argument completers
# Via: https://gist.github.com/indented-automation/26c637fb530c4b168e62c72582534f5b
Function Global:Get-ArgumentCompleter {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Switch]$Native
    )

    # Retrieve the execution context
    $LocalPipelineType = [PowerShell].Assembly.GetType('System.Management.Automation.Runspaces.LocalPipeline')
    $GetExecutionContextFromTLS = $LocalPipelineType.GetMethod('GetExecutionContextFromTLS', [Reflection.BindingFlags]'NonPublic, Static')
    $InternalExecutionContext = $GetExecutionContextFromTLS.Invoke($null, [Reflection.BindingFlags]'NonPublic, Static', $null, $null, $PSCulture)

    # Retrieve the argument completers property
    if ($Native) {
        $ArgumentCompletersProperty = $InternalExecutionContext.GetType().GetProperty('NativeArgumentCompleters', [Reflection.BindingFlags]'Instance, NonPublic')
    } else {
        $ArgumentCompletersProperty = $InternalExecutionContext.GetType().GetProperty('CustomArgumentCompleters', [Reflection.BindingFlags]'Instance, NonPublic')
    }

    # Retrieve the argument completers
    $BindingFlags = [Reflection.BindingFlags]'GetProperty, Instance, NonPublic'
    $ArgumentCompleters = $ArgumentCompletersProperty.GetGetMethod($true).Invoke($InternalExecutionContext, $BindingFlags, $null, @(), $PSCulture)

    # Returns `$null` when there's no argument completers
    if (!$ArgumentCompleters) { return }

    foreach ($Completer in $ArgumentCompleters.Keys) {
        $Name, $Parameter = $Completer.Split(':')

        [PSCustomObject]@{
            CommandName   = $Name
            ParameterName = $Parameter
            Definition    = $ArgumentCompleters[$Completer]
        }
    }
}

#endregion

#region Maintenance

# Update PowerShell modules & built-in help
Function Global:Update-PowerShell {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        [Regex]$ExcludedModuleRegex = '^(Az|Microsoft\.(Entra|Graph)|VMware)(|\..+)',

        [Switch]$IncludeDscModules,
        [Switch]$SkipUninstallObsolete,
        [Switch]$SkipUpdateHelp,
        [Switch]$Force,

        [Parameter(DontShow)]
        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    try {
        $PSGetNames = 'Microsoft.PowerShell.PSResourceGet', 'PowerShellGet'
        $PSGetModule = Test-ModuleAvailable -Name $PSGetNames -Require 'Any' -PassThru
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    if ($PSGetModule.Name -eq $PSGetNames[0]) {
        $PSResourceGet = $true
    } elseif ($PSGetModule.Version.Major -eq 2) {
        $PSResourceGet = $false
    } else {
        if ($PSGetModule.Version.Major -gt 2) {
            $ExcMsg = 'PowerShellGet v3 beta release is unsupported.'
        } else {
            $ExcMsg = "PowerShellGet must be at least v2 but found v$($PSGetModule.Version)."
        }

        $ErrExc = [NotSupportedException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotSupported', $ErrCat, $PSGetModule)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    Write-Verbose -Message "Using $($PSGetModule.Name) v$($PSGetModule.Version)"

    # Newer PowerShell versions no longer ship with DSC support built-in. It's
    # instead provided as a separate module which may not have been installed.
    try {
        # The implicit import of the `PSDesiredStateConfiguration` module that
        # may occur below triggers several "What if" outputs, even though
        # `Get-Command` doesn't support `-WhatIf`. As this cmdlet doesn't
        # modify any state we temporarily disable `WhatIf` mode.
        $WhatIfOriginal = $WhatIfPreference
        $WhatIfPreference = $false

        $DscSupport = Get-Command -Name 'Get-DscResource' -ErrorAction 'Stop'
        Write-Verbose -Message "DSC support is available through the $($DscSupport.Source) module."
    } catch {
        $Msg = 'Unable to enumerate DSC modules as Get-DscResource command not available.'

        if ($IncludeDscModules) {
            $ErrExc = [Management.Automation.CommandNotFoundException]::new($Msg)
            $ErrExc.CommandName = 'Get-DscResource'
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'CommandNotFoundException', $ErrCat, 'Get-DscResource')
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $DscSupport = $false
        Write-Warning -Message $Msg
        Write-Warning -Message 'DSC resources will be updated as they cannot be separately enumerated.'
    } finally {
        $WhatIfPreference = $WhatIfOriginal
    }

    $WriteProgressParams = @{ Activity = 'Updating PowerShell modules' }
    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    Write-Progress @WriteProgressParams -Status 'Enumerating installed modules' -PercentComplete 1
    if ($PSResourceGet) {
        $InstalledModules = Get-InstalledPSResource -Verbose:$false
    } else {
        try {
            # Suppress verbose output on implicit import
            $VerboseOriginal = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'

            $InstalledModules = Get-InstalledModule -Verbose:$false
        } finally {
            $VerbosePreference = $VerboseOriginal
        }
    }

    # `Get-InstalledPSResource` returns all module versions while
    # `Get-InstalledModule` only returns the latest version, so technically the
    # uniqueness check is only applicable to `PSResourceGet`.
    $UniqueModules = @($InstalledModules.Name | Sort-Object -Unique)

    # Percentage of the total progress to use for module update progress
    $ProgressPercentUpdatesBase = 10
    if ($UniqueModules -contains 'AWS.Tools.Installer') {
        $ProgressPercentUpdatesSection = 80
    } else {
        $ProgressPercentUpdatesSection = 90
    }

    if (!$IncludeDscModules -and $DscSupport) {
        Write-Progress @WriteProgressParams -Status 'Enumerating DSC modules for exclusion' -PercentComplete 5

        try {
            # `Get-DscResource` likes to output multiple progress bars but
            # doesn't have the good manners to clean them up when it's done.
            # The result is a visual mess when we have our own progress bars.
            $ProgressOriginal = $Global:ProgressPreference
            $Global:ProgressPreference = 'SilentlyContinue'

            # `Get-DscResource` may output various errors, most often due to
            # duplicate resources. That's often the case with, for example, the
            # `PackageManagement` module being available in multiple locations.
            $DscModules = @(Get-DscResource -Module * -ErrorAction 'Ignore' -Verbose:$false | Select-Object -ExpandProperty 'ModuleName' -Unique)
        } finally {
            $Global:ProgressPreference = $ProgressOriginal
        }
    }

    if (Test-IsWindows) {
        $ScopePathCurrentUser = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        $ScopePathAllUsers = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
        $StringComparisonType = [StringComparison]::OrdinalIgnoreCase
    } else {
        $ScopePathCurrentUser = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        $ScopePathAllUsers = '/usr/local/share'
        $StringComparisonType = [StringComparison]::Ordinal
    }

    # Update all modules
    for ($i = 0; $i -lt $UniqueModules.Count; $i++) {
        $ModuleName = $UniqueModules[$i]
        $Module = $InstalledModules | Where-Object Name -EQ $ModuleName | Sort-Object -Property 'Version' | Select-Object -Last 1

        if ($ModuleName -match $ExcludedModuleRegex) {
            Write-Verbose -Message "Skipping excluded module: ${ModuleName}"
            continue
        }

        if (!$IncludeDscModules -and $DscSupport -and $ModuleName -in $DscModules) {
            Write-Verbose -Message "Skipping DSC module: ${ModuleName}"
            continue
        }

        if ($ModuleName -match '^AWS\.Tools\.' -and $Module.Repository -notmatch 'PSGallery') { continue }

        $UpdateParams = @{
            Name          = $ModuleName
            AcceptLicense = $true
            ErrorAction   = 'Stop'
            Verbose       = $false
        }

        if ($Module.InstalledLocation.StartsWith($ScopePathCurrentUser, $StringComparisonType)) {
            $UpdateParams['Scope'] = 'CurrentUser'
        } elseif ($Module.InstalledLocation.StartsWith($ScopePathAllUsers, $StringComparisonType)) {
            $UpdateParams['Scope'] = 'AllUsers'
        } else {
            Write-Warning -Message "Unable to determine install scope for module: ${ModuleName}"
            continue
        }

        $PercentComplete = ($i + 1) / $UniqueModules.Count * $ProgressPercentUpdatesSection + $ProgressPercentUpdatesBase
        Write-Progress @WriteProgressParams -Status "Updating ${ModuleName}" -PercentComplete $PercentComplete

        if ($PSCmdlet.ShouldProcess($ModuleName, 'Update')) {
            try {
                if ($PSResourceGet) {
                    Update-PSResource @UpdateParams
                } else {
                    Update-Module @UpdateParams
                }
            } catch { $PSCmdlet.WriteError($PSItem) }
        }
    }

    # The modular AWS Tools for PowerShell has its own update mechanism
    if ($UniqueModules -contains 'AWS.Tools.Installer' -and 'AWS.Tools.Installer' -notmatch $ExcludedModuleRegex) {
        if ($PSCmdlet.ShouldProcess('AWS.Tools', 'Update')) {
            $PercentComplete = $ProgressPercentUpdatesBase + $ProgressPercentUpdatesSection
            Write-Progress @WriteProgressParams -Status 'Updating AWS modules' -PercentComplete $PercentComplete

            try {
                Update-AWSToolsModule -CleanUp -Force -ErrorAction 'Stop'
            } catch { $PSCmdlet.WriteError($PSItem) }
        }
    }

    Write-Progress @WriteProgressParams -Completed

    if (!$SkipUninstallObsolete -and $PSCmdlet.ShouldProcess('Obsolete modules', 'Uninstall')) {
        $UninstallParams = @{ ErrorAction = 'Stop' }

        if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
            $UninstallParams['ProgressParentId'] = $WriteProgressParams['Id']
        }

        try {
            Uninstall-ObsoleteModule @UninstallParams
        } catch { $PSCmdlet.WriteError($PSItem) }
    }

    if (!$SkipUpdateHelp -and $PSCmdlet.ShouldProcess('PowerShell help', 'Update')) {
        try {
            Update-Help -Force:$Force -ErrorAction 'Stop'
        } catch {
            Write-Warning -Message 'Some errors were reported while updating PowerShell module help.'
        }
    }
}

#endregion

#region Object handling

# Compare two hashtables
Function Global:Compare-Hashtable {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]$Reference,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]$Difference,

        [ValidateSet('Default', 'Insensitive', 'Sensitive')]
        [String]$CaseMatching = 'Default'
    )

    $Results = [Collections.Generic.List[PSCustomObject]]::new()

    $AllKeys = ($Reference.Keys + $Difference.Keys) | Sort-Object -Unique
    foreach ($Key in $AllKeys) {
        $Result = [PSCustomObject]@{
            Key        = $Key
            Reference  = $null
            Difference = $null
        }

        if ($Reference.ContainsKey($Key) -and $Difference.ContainsKey($Key)) {
            $Identical = $false

            switch ($CaseMatching) {
                'Insensitive' {
                    if ($Reference[$Key] -ieq $Difference[$Key]) {
                        $Identical = $true
                    }
                }

                'Sensitive' {
                    if ($Reference[$Key] -ceq $Difference[$Key]) {
                        $Identical = $true
                    }
                }

                default {
                    if ($Reference[$Key] -eq $Difference[$Key]) {
                        $Identical = $true
                    }
                }
            }

            if ($Identical) { continue }

            $Result.Reference = $Reference[$Key]
            $Result.Difference = $Difference[$Key]
        } elseif ($Reference.ContainsKey($Key)) {
            $Result.Reference = $Reference[$Key]
        } else {
            $Result.Difference = $Difference[$Key]
        }

        $Results.Add($Result)
    }

    return $Results.ToArray()
}

# Compare the properties of two objects
# Via: https://learn.microsoft.com/en-au/archive/blogs/janesays/compare-all-properties-of-two-objects-in-windows-powershell
Function Global:Compare-ObjectProperties {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory)]
        [PSObject]$ReferenceObject,

        [Parameter(Mandatory)]
        [PSObject]$DifferenceObject,

        [String[]]$IgnoredProperties
    )

    $RefPropNames = @($ReferenceObject |
            Get-Member -MemberType 'Property', 'NoteProperty' |
            Select-Object -ExpandProperty 'Name' |
            Where-Object { $PSItem -notin $IgnoredProperties } )

    $DiffPropNames = @($DifferenceObject |
            Get-Member -MemberType 'Property', 'NoteProperty' |
            Select-Object -ExpandProperty 'Name' |
            Where-Object { $PSItem -notin $IgnoredProperties } )

    $AllPropNames = ($RefPropNames + $DiffPropNames) |
        Sort-Object |
        Select-Object -Unique

    $DifferentProperties = [Collections.Generic.List[PSCustomObject]]::new()

    foreach ($PropertyName in $AllPropNames) {
        $CompareObject = Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Property $PropertyName

        if ($CompareObject) {
            $DifferentProperty = [PSCustomObject]@{
                PropertyName   = $PropertyName
                ReferenceValue = $CompareObject | Where-Object SideIndicator -EQ '<=' | Select-Object -ExpandProperty $PropertyName
                DifferentValue = $CompareObject | Where-Object SideIndicator -EQ '=>' | Select-Object -ExpandProperty $PropertyName
            }

            $DifferentProperties.Add($DifferentProperty)
        }
    }

    if ($DifferentProperties) {
        return $DifferentProperties.ToArray()
    }
}

#endregion

#region Profile management

# Reload selected PowerShell profiles
Function Global:Update-Profile {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Switch]$RebuildCompletions,

        [Switch]$AllUsersAllHosts,
        [Switch]$AllUsersCurrentHost,
        [Switch]$CurrentUserAllHosts,
        [Switch]$CurrentUserCurrentHost
    )

    if ($RebuildCompletions) {
        $Env:DOTFILES_REBUILD_COMPLETIONS = $true
    } else {
        $Env:DOTFILES_REBUILD_COMPLETIONS = $null
    }

    if (!($AllUsersAllHosts -or $AllUsersCurrentHost -or $CurrentUserAllHosts -or $CurrentUserCurrentHost)) {
        $CurrentUserCurrentHost = $true
    }

    try {
        $ProfileTypes = 'AllUsersAllHosts', 'AllUsersCurrentHost', 'CurrentUserAllHosts', 'CurrentUserCurrentHost'
        foreach ($ProfileType in $ProfileTypes) {
            if (Get-Variable -Name $ProfileType -ValueOnly) {
                if (Test-Path -LiteralPath $profile.$ProfileType -PathType 'Leaf') {
                    Write-Verbose -Message "Sourcing ${ProfileType} from: $($profile.$ProfileType)"
                    . $profile.$ProfileType
                } else {
                    Write-Warning -Message "Skipping ${ProfileType} as it doesn't exist: $($profile.$ProfileType)"
                }
            }
        }
    } finally {
        $Env:DOTFILES_REBUILD_COMPLETIONS = $null
        Remove-Variable -Name 'ProfileType', 'ProfileTypes'
    }
}

#endregion

#region Security

# Disable TLS certificate validation
Function Global:Disable-TlsCertificateValidation {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if ($PSVersionTable.PSEdition -eq 'Core') {
        $ExcMsg = 'Unable to disable TLS certificate validation on PowerShell 6 or later.'
        $ErrExc = [NotSupportedException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PwshNotSupported', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $TrustAllCerts = @'
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

namespace DotFiles {
    public static class CertificateValidation {
        public static bool TrustAllCerts(object sender,
                                         X509Certificate certificate,
                                         X509Chain chain,
                                         SslPolicyErrors sslPolicyErrors) {
            return true;
        }
    }
}
'@

    Add-Type -TypeDefinition $TrustAllCerts
    $TrustAllCertsDelegate = [Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback], [DotFiles.CertificateValidation], 'TrustAllCerts')
    [Net.ServicePointManager]::ServerCertificateValidationCallback = $TrustAllCertsDelegate
}

#endregion

#region Shortcut functions

# Invoke `Format-List` selecting all properties
Function Global:fla {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject]$InputObject,

        [Switch]$Force
    )

    Begin {
        $Objects = [Collections.Generic.List[PSObject]]::new()
    }

    Process {
        $Objects.Add($InputObject)
    }

    End {
        $null = $PSBoundParameters.Remove('InputObject')
        $Objects | Format-List @PSBoundParameters -Property *
    }
}

# Invoke `Format-Table` selecting all properties
Function Global:fta {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject]$InputObject,

        [Switch]$Force
    )

    Begin {
        $Objects = [Collections.Generic.List[PSObject]]::new()
    }

    Process {
        $Objects.Add($InputObject)
    }

    End {
        $null = $PSBoundParameters.Remove('InputObject')
        $Objects | Format-Table @PSBoundParameters -Property *
    }
}

# Invoke `Get-Help` with `-Detailed`
Function Global:ghd {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Detailed @PSBoundParameters
}

# Invoke `Get-Help` with `-Examples`
Function Global:ghe {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Examples @PSBoundParameters
}

# Invoke `Get-Help` with `-Full`
Function Global:ghf {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Full @PSBoundParameters
}

# Retrieve `FileVersionInfo` from a file
Function Global:gvi {
    [CmdletBinding()]
    [OutputType([Diagnostics.FileVersionInfo])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path
    )

    Get-Item -Path $Path | Select-Object -ExpandProperty 'VersionInfo'
}

#endregion

Complete-DotFilesSection
