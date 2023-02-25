Start-DotFilesSection -Type 'Functions' -Name 'PowerShell'

#region Internals

# Retrieve custom argument completers
# Via: https://gist.github.com/indented-automation/26c637fb530c4b168e62c72582534f5b
Function Get-ArgumentCompleter {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Switch]$Native
    )

    $BindingFlags = [Reflection.BindingFlags]'NonPublic, Static'
    $LocalPipelineType = [PowerShell].Assembly.GetType('System.Management.Automation.Runspaces.LocalPipeline')
    $GetExecutionContextFromTLS = $LocalPipelineType.GetMethod('GetExecutionContextFromTLS', $BindingFlags)
    $InternalExecutionContext = $GetExecutionContextFromTLS.Invoke($null, $BindingFlags, $null, $null, $PSCulture)

    $BindingFlags = [Reflection.BindingFlags]'Instance, NonPublic'
    if ($Native) {
        $ArgumentCompletersPropertyName = 'NativeArgumentCompleters'
    } else {
        $ArgumentCompletersPropertyName = 'CustomArgumentCompleters'
    }
    $ArgumentCompletersProperty = $InternalExecutionContext.GetType().GetProperty($ArgumentCompletersPropertyName, $BindingFlags)

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
        [Switch]$SkipUninstallObsolete,
        [Switch]$SkipUpdateHelp,
        [Switch]$Force,

        [ValidateRange(-1, [Int]::MaxValue)]
        [Int]$ProgressParentId
    )

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

        if ($PowerShellGet) {
            try {
                $PowerShellGet | Import-Module -ErrorAction Stop -Verbose:$false
                $Script:PsGetV2 = $true
                return $true
            } catch {
                Write-Error -Message 'Failed to import PowerShellGet v2 module side-by-side.'
            }
        } else {
            Write-Error -Message 'No PowerShellGet v2 module was found for importing side-by-side.'
        }

        return $false
    }

    $PowerShellGet = Test-ModuleAvailable -Name 'PowerShellGet' -PassThru

    $Script:PsGetV2 = $false
    $Script:PsGetV3 = $false
    $Script:PsGetV2AttemptedSxS = $false

    if ($PowerShellGet.Version.Major -eq 2) {
        $Script:PsGetV2 = $true
    } elseif ($PowerShellGet.Version.Major -ge 3) {
        $Script:PsGetV3 = $true
    } else {
        throw 'PowerShellGet must be at least v2 but found: {0}' -f $PowerShellGet.Version
    }

    Write-Verbose -Message ('Using PowerShellGet v{0}' -f $PowerShellGet.Version)

    # Not all platforms have DSC support as part of PowerShell itself
    $DscSupported = Get-Command -Name 'Get-DscResource' -ErrorAction Ignore
    if ($IncludeDscModules -and !$DscSupported) {
        throw 'Unable to enumerate DSC modules as Get-DscResource command not available.'
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
        $InstalledModules = Get-InstalledModule -Verbose:$false
    }

    # Get-PSResource returns all module versions while Get-InstalledModule only
    # returns the latest version, making this redundant with PowerShellGet v3.
    $UniqueModules = $InstalledModules.Name | Sort-Object -Unique

    # Percentage of the total progress for updating modules
    $ProgressPercentUpdatesBase = 10
    if ($UniqueModules -contains 'AWS.Tools.Installer') {
        $ProgressPercentUpdatesSection = 80
    } else {
        $ProgressPercentUpdatesSection = 90
    }

    if (!$IncludeDscModules -and $DscSupported) {
        Write-Progress @WriteProgressParams -Status 'Enumerating DSC modules for exclusion' -PercentComplete 5

        # Get-DscResource likes to output multiple progress bars but doesn't
        # have the good manners to clean them up. The result is a visual mess
        # when we've got our own progress bars.
        $OriginalProgressPreference = $ProgressPreference
        Set-Variable -Name 'ProgressPreference' -Scope Global -Value 'Ignore' -WhatIf:$false

        try {
            # Get-DscResource may output various errors, most often due to
            # duplicate resources. That's often the case with, for example, the
            # PackageManagement module being available in multiple locations.
            $DscModules = @(Get-DscResource -Module * -ErrorAction Ignore -Verbose:$false | Select-Object -ExpandProperty 'ModuleName' -Unique)
        } finally {
            Set-Variable -Name 'ProgressPreference' -Scope Global -Value $OriginalProgressPreference -WhatIf:$false
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
    for ($ModuleIdx = 0; $ModuleIdx -lt $UniqueModules.Count; $ModuleIdx++) {
        $ModuleName = $UniqueModules[$ModuleIdx]
        $Module = $InstalledModules | Where-Object Name -EQ $ModuleName | Sort-Object -Property 'Version' | Select-Object -Last 1

        if ($ModuleName -match $ExcludedModuleRegex) {
            Write-Verbose -Message ('Skipping excluded module: {0}' -f $ModuleName)
            continue
        }

        if (!$IncludeDscModules -and $DscSupported -and $ModuleName -in $DscModules) {
            Write-Verbose -Message ('Skipping DSC module: {0}' -f $ModuleName)
            continue
        }

        if ($ModuleName -match '^AWS\.Tools\.' -and $Module.Repository -notmatch 'PSGallery') {
            continue
        }

        $UpdateParams = @{
            Name          = $ModuleName
            AcceptLicense = $true
        }

        if ($Module.InstalledLocation.StartsWith($ScopePathCurrentUser)) {
            $UpdateParams['Scope'] = 'CurrentUser'
        } elseif ($Module.InstalledLocation.StartsWith($ScopePathAllUsers)) {
            $UpdateParams['Scope'] = 'AllUsers'
        } else {
            Write-Warning -Message ('Unable to determine install scope for module: {0}' -f $Module)
            continue
        }

        $PercentComplete = ($ModuleIdx + 1) / $UniqueModules.Count * $ProgressPercentUpdatesSection + $ProgressPercentUpdatesBase
        Write-Progress @WriteProgressParams -Status ('Updating {0}' -f $ModuleName) -PercentComplete $PercentComplete

        if ($PSCmdlet.ShouldProcess($ModuleName, 'Update')) {
            if ($Script:PsGetV3 -and $ModuleName -notin $PsGetV3Blacklist) {
                Update-PSResource @UpdateParams -Verbose:$false
                continue
            }

            # If PowerShellGet v2 has not been imported then we're using
            # PowerShellGet v3 but need to fallback to the previous major
            # version for this module due to a compatibility issue.
            if (!$Script:PsGetV2) {
                $ImportSxS = Import-PsGetV2SxS
                if (!$ImportSxS) {
                    Write-Warning -Message ('Unable to update module as PowerShellGet v2 is unavailable: {0}' -f $ModuleName)
                    continue
                }
            }

            Update-Module @UpdateParams -Verbose:$false
        }
    }

    # The modular AWS Tools for PowerShell has its own mechanism
    if ($UniqueModules -contains 'AWS.Tools.Installer' -and 'AWS.Tools.Installer' -notmatch $ExcludedModuleRegex) {
        # The Update-AWSToolsModule function is not yet compatible with
        # PowerShellGet v3. If we're currently using PowerShellGet v3 but
        # PowerShellGet v2 is available attempt to import it side-by-side.
        if (!$Script:PsGetV2) {
            $ImportSxS = Import-PsGetV2SxS
            if (!$ImportSxS) {
                Write-Warning -Message 'Unable to update AWS modules as PowerShellGet v2 is unavailable.'
                continue
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
            Update-Help -Force:$Force -ErrorAction Stop
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
                Default {
                    if ($Reference[$Key] -eq $Difference[$Key]) {
                        $Identical = $true
                    }
                }
            }

            if ($Identical) {
                continue
            }

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
# Via: https://blogs.technet.microsoft.com/janesays/2017/04/25/compare-all-properties-of-two-objects-in-windows-powershell/
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

    $ObjProps = @()
    $ObjProps += $ReferenceObject | Get-Member -MemberType Property, NoteProperty | Select-Object -ExpandProperty 'Name'
    $ObjProps += $DifferenceObject | Get-Member -MemberType Property, NoteProperty | Select-Object -ExpandProperty 'Name'
    $ObjProps = $ObjProps | Sort-Object | Select-Object -Unique

    if ($IgnoredProperties) {
        $ObjProps = $ObjProps | Where-Object { $_ -notin $IgnoredProperties }
    }

    $ObjDiffs = [Collections.Generic.List[PSCustomObject]]::new()
    foreach ($Property in $ObjProps) {
        $Diff = Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Property $Property

        if ($Diff) {
            $DiffProps = [PSCustomObject]@{
                PropertyName = $Property
                RefValue     = $Diff | Where-Object SideIndicator -EQ '<=' | Select-Object -ExpandProperty $($Property)
                DiffValue    = $Diff | Where-Object SideIndicator -EQ '=>' | Select-Object -ExpandProperty $($Property)
            }

            $ObjDiffs.Add($DiffProps)
        }
    }

    if ($ObjDiffs) {
        return $ObjDiffs.ToArray()
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

            if (!$Comparison) {
                continue
            }

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
        [Switch]$AllUsersAllHosts,
        [Switch]$AllUsersCurrentHost,
        [Switch]$CurrentUserAllHosts,
        [Switch]$CurrentUserCurrentHost
    )

    if (!($AllUsersAllHosts -or $AllUsersCurrentHost -or $CurrentUserAllHosts -or $CurrentUserCurrentHost)) {
        $CurrentUserCurrentHost = $true
    }

    $ProfileTypes = 'AllUsersAllHosts', 'AllUsersCurrentHost', 'CurrentUserAllHosts', 'CurrentUserCurrentHost'
    foreach ($ProfileType in $ProfileTypes) {
        if (Get-Variable -Name $ProfileType -ValueOnly) {
            if (Test-Path -LiteralPath $profile.$ProfileType -PathType Leaf) {
                Write-Verbose -Message ('Sourcing {0} from: {1}' -f $ProfileType, $profile.$ProfileType)
                . $profile.$ProfileType
            } else {
                Write-Warning -Message ("Skipping {0} as it doesn't exist: {1}" -f $ProfileType, $profile.$ProfileType)
            }
        }
    }

    Remove-Variable -Name ($ProfileTypes + @('ProfileType', 'ProfileTypes'))
}

#endregion

#region Security

# Disable TLS certificate validation
Function Disable-TlsCertificateValidation {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'Unable to disable TLS certificate validation on PowerShell Core.'
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

# Invoke Format-List selecting all properties
Function fla {
    [CmdletBinding()]
    [OutputType($null)]
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
        $Objects | Format-List -Property * @PSBoundParameters
    }
}

# Invoke Format-Table selecting all properties
Function fta {
    [CmdletBinding()]
    [OutputType($null)]
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
        $Objects | Format-Table -Property * @PSBoundParameters
    }
}

# Invoke Get-Help with -Detailed
Function ghd {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Detailed @PSBoundParameters
}

# Invoke Get-Help with -Examples
Function ghe {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Examples @PSBoundParameters
}

# Invoke Get-Help with -Full
Function ghf {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    Get-Help -Full @PSBoundParameters
}

# Retrieve FileVersionInfo from a file
Function gvi {
    [CmdletBinding()]
    [OutputType([Diagnostics.FileVersionInfo])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path
    )

    Get-Item -Path $Path | Select-Object -ExpandProperty VersionInfo
}

#endregion

Complete-DotFilesSection
