$null = Start-DotFilesSection -Type 'Functions' -Name 'PowerShell'

#region .NET

# Retrieve all type accelerators
Function Get-TypeAccelerator {
    [CmdletBinding()]
    [OutputType([Collections.Generic.Dictionary[String, Type]])]
    Param()

    [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::get_Get()
}

# Retrieve the constructors for a type
Function Get-TypeConstructor {
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

            if ($ConstructorParams.Count -gt 0) {
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
Function Get-TypeMethod {
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

            if ($MethodParams.Count -gt 0) {
                $FormattedMethodParams = @($MethodParams | ForEach-Object { $PSItem.ToString() })
                $FormattedParams = "$($Type.FullName)($($FormattedMethodParams -join ', '))"
            } else {
                $FormattedParams = "$($Type.FullName)()"
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
Function Get-ArgumentCompleter {
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
Function Update-PowerShell {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        [Regex]$ExcludedModuleRegex = '^(Az|Microsoft\.Graph|VMware)(|\..+)',
        [String[]]$PsGetV3Blacklist = @('ExchangeOnlineManagement', 'PnP.PowerShell'),

        [Switch]$IncludeDscModules,
        [Switch]$SkipUpdateHelp,
        [Switch]$SkipUninstallObsolete,
        [Switch]$Force,

        [ValidateRange(-1, [SByte]::MaxValue)]
        [SByte]$ProgressParentId
    )

    # Attempt to import the PowerShellGet v2 module side-by-side with the v3
    # module when using the latter but we encounter compatibility issues.
    Function Import-PsGetV2SxS {
        [CmdletBinding()]
        [OutputType([Boolean])]
        Param()

        if ($Script:PsGetV2) {
            return $true
        }

        if ($Script:PsGetV2AttemptedSxS) {
            return $false
        }

        Write-Verbose -Message 'Attempting to import PowerShellGet v2 side-by-side ...'
        $Script:PsGetV2AttemptedSxS = $true

        $PowerShellGet = Get-Module -Name 'PowerShellGet' -ListAvailable -Verbose:$false |
            Where-Object Version -Match '^2\.' |
            Sort-Object -Property 'Version' -Descending |
            Select-Object -First 1

        if (!$PowerShellGet) {
            $ErrMsg = 'PowerShellGet v2 module not available for side-by-side import.'
            $ErrExc = [IO.FileNotFoundException]::new($ErrMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotFound', $ErrCat, 'PowerShellGet')
            $PSCmdlet.WriteError($ErrRec)
            return $false
        }

        try {
            $PowerShellGet | Import-Module -ErrorAction 'Stop' -Verbose:$false
            $Script:PsGetV2 = $true
        } catch {
            $ErrMsg = 'Failed to import PowerShellGet v2 module side-by-side.'
            $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotFound', $ErrCat, 'PowerShellGet')
            $PSCmdlet.WriteError($ErrRec)
            return $false
        }

        return $true
    }

    $PowerShellGet = Test-ModuleAvailable -Name 'PowerShellGet' -PassThru

    if ($PowerShellGet.Version.Major -lt 2) {
        $ErrMsg = 'PowerShellGet v2 or later was not found.'
        $ErrExc = [IO.FileNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotFound', $ErrCat, 'PowerShellGet')
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Script:PsGetV2 = $false
    $Script:PsGetV2AttemptedSxS = $false
    $Script:PsGetV3 = $false

    if ($PowerShellGet.Version.Major -ge 3) {
        $Script:PsGetV3 = $true
    } else {
        $Script:PsGetV2 = $true
    }

    Write-Verbose -Message "Using PowerShellGet v$($PowerShellGet.Version)"

    # Newer PowerShell versions no longer ship with DSC support built-in. It's
    # instead provided as a separate module which may not be installed.
    try {
        $DscSupported = $false
        $DscSupported = Get-Command -Name 'Get-DscResource' -ErrorAction 'Stop'
    } catch {
        if ($IncludeDscModules) {
            $ErrMsg = 'Unable to enumerate DSC modules as Get-DscResource command not available.'
            $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSCommandNotFound', $ErrCat, 'Get-DscResource')
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }

    $WriteProgressParams = @{
        Activity = 'Updating PowerShell modules'
    }

    if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
        $WriteProgressParams['ParentId'] = $ProgressParentId
        $WriteProgressParams['Id'] = $ProgressParentId + 1
    }

    Write-Progress @WriteProgressParams -Status 'Enumerating installed modules' -PercentComplete 1
    if ($Script:PsGetV3) {
        $InstalledModules = Get-PSResource -Verbose:$false
    } else {
        try {
            # Suppress verbose output on implicit import
            $VerboseOriginal = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'

            $InstalledModules = Get-InstalledModule -Verbose:$false
        } finally {
            $Global:VerbosePreference = $VerboseOriginal
        }
    }

    # `Get-PSResource` returns all module versions while `Get-InstalledModule`
    # only returns the latest version, so technically the uniqueness check is
    # only applicable to PowerShellGet v3.
    $UniqueModules = @($InstalledModules.Name | Sort-Object -Unique)

    # Percentage of the total progress to use for module update progress
    $ProgressPercentUpdatesBase = 10
    if ($UniqueModules -contains 'AWS.Tools.Installer') {
        $ProgressPercentUpdatesSection = 80
    } else {
        $ProgressPercentUpdatesSection = 90
    }

    if (!$IncludeDscModules -and $DscSupported) {
        Write-Progress @WriteProgressParams -Status 'Enumerating DSC modules for exclusion' -PercentComplete 5

        try {
            # `Get-DscResource` likes to output multiple progress bars but
            # doesn't have the good manners to clean them up when it's done.
            # The result is a visual mess when we have our own progress bars.
            $ProgressOriginal = $Global:ProgressPreference
            $Global:ProgressPreference = 'Ignore'

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
    } else {
        $ScopePathCurrentUser = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        $ScopePathAllUsers = '/usr/local/share'
    }

    # Update all modules compatible with PowerShellGet
    for ($i = 0; $i -lt $UniqueModules.Count; $i++) {
        $ModuleName = $UniqueModules[$i]
        $Module = $InstalledModules | Where-Object Name -EQ $ModuleName | Sort-Object -Property 'Version' | Select-Object -Last 1

        if ($ModuleName -match $ExcludedModuleRegex) {
            Write-Verbose -Message "Skipping excluded module: ${ModuleName}"
            continue
        }

        if (!$IncludeDscModules -and $DscSupported -and $ModuleName -in $DscModules) {
            Write-Verbose -Message "Skipping DSC module: ${ModuleName}"
            continue
        }

        if ($ModuleName -match '^AWS\.Tools\.' -and $Module.Repository -notmatch 'PSGallery') { continue }

        $UpdateParams = @{
            Name          = $ModuleName
            AcceptLicense = $true
        }

        if ($Module.InstalledLocation.StartsWith($ScopePathCurrentUser)) {
            $UpdateParams['Scope'] = 'CurrentUser'
        } elseif ($Module.InstalledLocation.StartsWith($ScopePathAllUsers)) {
            $UpdateParams['Scope'] = 'AllUsers'
        } else {
            Write-Warning -Message "Unable to determine install scope for module: ${ModuleName}"
            continue
        }

        $PercentComplete = ($i + 1) / $UniqueModules.Count * $ProgressPercentUpdatesSection + $ProgressPercentUpdatesBase
        Write-Progress @WriteProgressParams -Status "Updating ${ModuleName}" -PercentComplete $PercentComplete

        if ($PSCmdlet.ShouldProcess($ModuleName, 'Update')) {
            if ($Script:PsGetV3 -and $ModuleName -notin $PsGetV3Blacklist) {
                Update-PSResource @UpdateParams -Verbose:$false
                continue
            }

            # If PowerShellGet v2 has not been imported then we must be using
            # PowerShellGet v3. The module which we're about to update has a
            # compatibility issue with PowerShellGet v3 so try to fallback to
            # PowerShellGet v2.
            if (!$Script:PsGetV2) {
                $ImportSxS = Import-PsGetV2SxS
                if (!$ImportSxS) {
                    Write-Warning -Message "Unable to update module as PowerShellGet v2 is unavailable: ${ModuleName}"
                    continue
                }
            }

            Update-Module @UpdateParams -Verbose:$false
        }
    }

    # The modular AWS Tools for PowerShell has its own update mechanism
    if ($UniqueModules -contains 'AWS.Tools.Installer' -and 'AWS.Tools.Installer' -notmatch $ExcludedModuleRegex) {
        # The `Update-AWSToolsModule` function is not yet compatible with
        # PowerShellGet v3. If we're currently using PowerShellGet v3 but
        # PowerShellGet v2 is available attempt to import it side-by-side.
        if (!$Script:PsGetV2) {
            $ImportSxS = Import-PsGetV2SxS
            if (!$ImportSxS) {
                Write-Warning -Message 'Unable to update AWS modules as PowerShellGet v2 is unavailable.'
            }
        }

        if ($Script:PsGetV2) {
            $PercentComplete = $ProgressPercentUpdatesBase + $ProgressPercentUpdatesSection
            Write-Progress @WriteProgressParams -Status 'Updating AWS modules' -PercentComplete $PercentComplete

            if ($PSCmdlet.ShouldProcess('AWS.Tools', 'Update')) {
                Update-AWSToolsModule -CleanUp -Force
            }
        }
    }

    Write-Progress @WriteProgressParams -Completed

    if (!$SkipUninstallObsolete -and $PSCmdlet.ShouldProcess('Obsolete modules', 'Uninstall')) {
        if ($PSBoundParameters.ContainsKey('ProgressParentId')) {
            Uninstall-ObsoleteModule -ProgressParentId $WriteProgressParams['Id']
        } else {
            Uninstall-ObsoleteModule
        }
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
Function Compare-Hashtable {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Reference,

        [Parameter(Mandatory)]
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
Function Compare-ObjectProperties {
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

# Compare the properties of multiple objects against a baseline
Function Compare-ObjectPropertiesMatrix {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [Array]$Objects,

        [ValidateNotNullOrEmpty()]
        [PSObject]$ReferenceObject,

        [String[]]$IgnoredProperties
    )

    Begin {
        $ComparedObjects = [Collections.Generic.List[Object]]::new()
        $DifferentProperties = [Collections.Generic.List[String]]::new()

        $DiscoverReferenceObject = $false
        if (!$ReferenceObject) {
            $DiscoverReferenceObject = $true
        }

        $NumProcessed = 0
    }

    Process {
        foreach ($Object in $Objects) {
            if ($Object -is [Array]) {
                Write-Warning -Message 'Skipping nested array.'
                continue
            }

            if ($DiscoverReferenceObject) {
                $ReferenceObject = $Object
                $DiscoverReferenceObject = $false
                continue
            }

            $Comparison = Compare-ObjectProperties -ReferenceObject $ReferenceObject -DifferenceObject $Object
            $NumProcessed++

            if (!$Comparison) { continue }

            foreach ($PropertyName in $Comparison.PropertyName) {
                if ($DifferentProperties -notcontains $PropertyName) {
                    $DifferentProperties.Add($PropertyName)
                }
            }

            $ComparedObjects.Add($Object)
        }
    }

    End {
        if (!$ReferenceObject) {
            throw 'No reference object to compare against.'
        }

        if ($NumProcessed -eq 0) {
            throw 'No objects provided to compare against.'
        }

        if ($ComparedObjects.Count -eq 0) {
            Write-Warning -Message 'Found no differences among objects.'
            return
        }

        $FilteredProperties = @($DifferentProperties | Sort-Object -Unique | Where-Object { $_ -notin $IgnoredProperties })
        $ReferenceObject | Select-Object -Property $FilteredProperties
        $ComparedObjects | Select-Object -Property $FilteredProperties
    }
}

#endregion

#region Profile management

# Reload selected PowerShell profiles
Function Update-Profile {
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
Function Disable-TlsCertificateValidation {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if ($PSVersionTable.PSEdition -eq 'Core') {
        $ErrMsg = 'Unable to disable TLS certificate validation on PowerShell 6 or later.'
        $ErrExc = [NotSupportedException]::new($ErrMsg)
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
Function fla {
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
Function fta {
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
Function ghd {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Detailed @PSBoundParameters
}

# Invoke `Get-Help` with `-Examples`
Function ghe {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Examples @PSBoundParameters
}

# Invoke `Get-Help` with `-Full`
Function ghf {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Full @PSBoundParameters
}

# Retrieve `FileVersionInfo` from a file
Function gvi {
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
