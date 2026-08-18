# PowerShell
# https://learn.microsoft.com/en-au/powershell/
# https://github.com/PowerShell/PowerShell

$null = Start-DotFilesSection -Type 'Settings' -Name 'PowerShell'

#region Default parameter values

# about_Parameters_Default_Values
# https://learn.microsoft.com/en-au/powershell/module/microsoft.powershell.core/about/about_parameters_default_values

# Default values for parameters of cmdlets and advanced functions
#
# Default: (empty hash table)
# Type:    DefaultParameterDictionary
# Added:   3.0
switch ($PSVersionTable.PSEdition) {
    'Core' {
        # `Update-Help`: `en-GB` locale is not available
        $PSDefaultParameterValues['Update-Help:UICulture'] = 'en-US'
    }

    'Desktop' {
        # `Out-File`: Default to UTF-8 encoding
        $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
    }

    default {
        Write-DotFilesMessage -Type 'Warning' -Message 'Unknown PowerShell edition.'
    }
}

#endregion

#region Event logging

# All settings were introduced in PowerShell 3.0, use a `Boolean` type, and are
# unset by default. The documented per-setting default refers to the effective
# behaviour when the variable is unset.

# Log errors and exceptions in command initialisation and processing
#
# Default: $false
#$Global:LogCommandHealthEvent =

# Log starting and stopping of commands, command pipelines, and security
# exceptions in command discovery.
#
# Default: $false
#$Global:LogCommandLifecycleEvent =

# Log errors and failures for sessions
#
# Default: $true
#$Global:LogEngineHealthEvent =

# Log opening and closing of sessions
#
# Default: $true
#$Global:LogEngineLifecycleEvent =

# Log provider, lookup, and invocation errors
#
# Default: $true
#$Global:LogProviderHealthEvent =

# Log addition and removal of providers
#
# Default: $true
#$Global:LogProviderLifecycleEvent =

#endregion

#region Object pipeline

# Save the output of the last command in a global variable
#
# This function is automatically invoked by PowerShell internally appending it
# to the end of every top-level interactive pipeline. The `Out-Default` cmdlet
# would normally be invoked, but functions have higher precedence, so we can
# override the default behaviour by defining a function of the same name.
Function Global:Out-Default {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [OutputType([Void])]
    Param()

    $Input | Tee-Object -Variable 'LastObject' | Microsoft.PowerShell.Core\Out-Default
    $Global:LastObject = $LastObject
}

#endregion

#region Output streams

# about_Output_Streams
# https://learn.microsoft.com/en-au/powershell/module/microsoft.powershell.core/about/about_output_streams
#
# All settings use an `ActionPreference` enumeration:
# - Continue
# - Inquire
# - SilentlyContinue
# - Stop
# - Ignore (Added in 3.0)
# - Suspend (Added in 4.0, unsupported since 6.0)
# - Break (Added in 7.0)

# Behaviour for handling of non-terminating errors (stream 2)
#
# Default: Continue
# Added:   1.0
#$Global:ErrorActionPreference =

# Behaviour for handling of warning messages (stream 3)
#
# Default: Continue
# Added:   1.0
#$Global:WarningPreference =

# Behaviour for handling of verbose messages (stream 4)
#
# Default: SilentlyContinue
# Added:   1.0
#$Global:VerbosePreference =

# Behaviour for handling of debugging messages (stream 5)
#
# Default: SilentlyContinue
# Added:   1.0
#$Global:DebugPreference =

# Behaviour for handling of information updates (stream 6)
#
# Default: SilentlyContinue
# Added:   5.0
#$Global:InformationPreference =

# Behaviour for handling of progress updates
#
# The progress stream has no stream number as it does not support redirection.
#
# Default: Continue
# Added:   1.0
#$Global:ProgressPreference =

#endregion

#region PowerShell sessions

# about_PSSessions
# https://learn.microsoft.com/en-au/powershell/module/microsoft.powershell.core/about/about_pssessions
#
# All settings were introduced in PowerShell 2.0.

# Default application name for remote commands that use WS-Management
#
# Default: wsman
# Type:    String
#$Global:PSSessionApplicationName =

# Default session configuration for creating new sessions
#
# Default: http://schemas.microsoft.com/powershell/Microsoft.PowerShell
# Type:    String
#$Global:PSSessionConfigurationName =

# Default values for advanced user options in a remote session
#
# Default: (complex type)
# Type:    PSSessionOption
#$Global:PSSessionOption =

#endregion

#region Resource limits

# All settings were introduced in PowerShell 1.0 and use a `Int32` type.

# Maximum number of aliases
#
# Default: 4096
# Removed: 6.0
#$Global:MaximumAliasCount =

# Maximum number of drives
#
# Default: 4096
# Removed: 6.0
#$Global:MaximumDriveCount =

# Maximum number of errors retained in the error history
#
# Default: 256
# Removed: 6.0
#$Global:MaximumErrorCount =

# Maximum number of functions
#
# Default: 4096
# Removed: 6.0
#$Global:MaximumFunctionCount =

# Maximum number of commands retained in the command history
#
# Default differs by version:
# >=3.0: 4096
#  <3.0: 64
#$Global:MaximumHistoryCount =

# Maximum number of variables
#
# Default: 4096
# Removed: 6.0
#$Global:MaximumVariableCount =

#endregion

#region Terminal output

# about_ANSI_Terminals
# https://learn.microsoft.com/en-au/powershell/module/microsoft.powershell.core/about/about_ansi_terminals

# Display format for error messages
#
# Valid values:
# - NormalView (default prior to 7.0)
# - CategoryView
# - ConciseView (Added in 7.0, default)
# - DetailedView (Added in 7.2)
#
# Type:    ErrorView enumeration
# Added:   1.0
#$Global:ErrorView =

# Number of elements to display for enumerable objects
#
# Default: 4
# Type:    Int32
# Added:   1.0
#$Global:FormatEnumerationLimit =

# ANSI escape sequences for text rendering in the terminal
#
# Default: (complex type)
# Type:    PSStyle
# Added:   7.2
#$Global:PSStyle =

#endregion

#region Miscellaneous

# Minimum impact level which requires confirmation
#
# Valid values:
# - None
# - Low
# - Medium
# - High
#
# Default: High
# Type:    ConfirmImpact enumeration
# Added:   1.0
#$Global:ConfirmPreference =

# Output Field Separator (OFS) for separating the elements of an array
# converted to a string.
#
# If unset, a single space is used.
#
# Default: (unset)
# Type:    String
# Added:   1.0
#$Global:OFS =

# Character encoding for piping data into native applications
#
# Default differs by version:
# >=6.0: System.Text.UTF8Encoding
#  <6.0: System.Text.ASCIIEncoding
#
# Type:    Encoding
# Added:   1.0
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $Global:OutputEncoding = [Text.UTF8Encoding]::new()
}

# Address of default email server used by cmdlets that send email
#
# Default: (empty)
# Type:    String
# Added:   3.0
#$Global:PSEmailServer =

# Behaviour for automatically importing modules
#
# Valid values:
# - None
# - ModuleQualified
# - All
#
# If unset, the `All` behaviour is used.
#
# Default: (unset)
# Type:    PSModuleAutoLoadingPreference enumeration
# Added:   3.0
#$Global:PSModuleAutoLoadingPreference =

# Behaviour for parsing the command line for native commands
#
# Valid values:
# - Legacy
# - Standard
# - Windows
#
# On Windows the default is `Windows`, while all other platforms default to
# `Standard`. If unset, the `Standard` behaviour is used.
#
# Type:    NativeArgumentPassingStyle enumeration
# Added:   7.3
#$Global:PSNativeCommandArgumentPassing =

# Issue errors according to `$ErrorActionPreference` for native commands which
# return a non-zero exit code.
#
# Default: $false
# Type:    Boolean
# Added:   7.4
#$Global:PSNativeCommandUseErrorActionPreference =

# Default path used by `Start-Transcript` to save a session transcript
#
# If unset, a platform-specific directory is used:
# - Linux or macOS: `$HOME`
# - Windows:        `Documents` known folder (e.g. `%USERPROFILE%\Documents`)
#
# The default transcript file name differs by version:
# >=5.0: PowerShell_transcript.<computername>.<random>.<timestamp>.txt
#  <5.0: PowerShell_transcript.<timestamp>.txt
#
# Type:    String
# Added:   1.0
#$Global:Transcript =

# Always write help errors to the pipeline and show additional warnings
#
# If unset, equivalent to `$false`.
#
# Default: (unset)
# Type:    Boolean
# Added:   3.0
#$Global:VerboseHelpErrors =

# Automatically enable `WhatIf` on supported commands
#
# Default: $false
# Type:    Boolean
# Added:   1.0
#$Global:WhatIfPreference =

#endregion

Complete-DotFilesSection
