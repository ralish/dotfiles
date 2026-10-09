# PSScriptAnalyzer settings
#
# Last reviewed release: v1.25.0

@{
    # A wildcard does not enable rules derived from `ConfigurableRule` which
    # are disabled by default. These rules must still be explicitly enabled.
    #
    # Configurable rules which default to enabled:
    # - PSAvoidOverwritingBuiltInCmdlets
    # - PSAvoidPositionalParameters
    # - PSProvideCommentHelp
    # - PSUseSingularNouns
    #
    # Configurable rules which default to disabled:
    # - PSAlignAssignmentStatement
    # - PSAvoidExclaimOperator
    # - PSAvoidLongLines
    # - PSAvoidSemicolonsAsLineTerminators
    # - PSAvoidUsingDoubleQuotesForConstantString
    # - PSPlaceCloseBrace
    # - PSPlaceOpenBrace
    # - PSUseCompatibleCommands
    # - PSUseCompatibleSyntax
    # - PSUseCompatibleTypes
    # - PSUseConsistentIndentation
    # - PSUseConsistentParameterSetName
    # - PSUseConsistentParametersKind
    # - PSUseConsistentWhitespace
    # - PSUseConstrainedLanguageMode
    # - PSUseCorrectCasing
    # - PSUseSingleValueFromPipelineParameter
    IncludeRules = @('*')

    ExcludeRules = @()

    Rules = @{
        # Compatibility rules
        PSAvoidOverwritingBuiltInCmdlets = @{
            Enable            = $true
            # If unset, the default is based on the PowerShell version:
            # - core-6.1.0-windows              PowerShell 6.0 or later
            # - desktop-5.1.14393.206-windows   PowerShell 5.1 or earlier
            PowerShellVersion = @()
        }

        PSUseCompatibleCmdlets = @{
            compatibility = @()
        }

        PSUseCompatibleCommands = @{
            Enable         = $false
            # If unset, uses the default compatibility profiles directory
            ProfileDirPath = ''
            TargetProfiles = @()
            IgnoreCommands = @()
        }

        PSUseCompatibleSyntax = @{
            Enable         = $false
            # Only major versions from v3.0 are supported
            # If unset, defaults to: 5.0, 6.0, 7.0
            TargetVersions = @()
        }

        PSUseCompatibleTypes = @{
            Enable         = $false
            # If unset, uses the default compatibility profiles directory
            ProfileDirPath = ''
            TargetProfiles = @()
            IgnoreTypes    = @()
        }

        # General rules
        PSAlignAssignmentStatement = @{
            Enable                                  = $true
            CheckHashtable                          = $true
            AlignHashtableKvpWithInterveningComment = $true
            CheckEnums                              = $true
            AlignEnumMemberWithInterveningComment   = $true
            IncludeValuelessEnumMembers             = $true
        }

        PSAvoidExclaimOperator = @{
            Enable = $false
        }

        PSAvoidLongLines = @{
            Enable            = $false
            MaximumLineLength = 119
        }

        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }

        PSAvoidUsingCmdletAliases = @{
            allowlist = @()
        }

        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $true
        }

        PSAvoidUsingPositionalParameters = @{
            Enable           = $true
            CommandAllowList = @()
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $false
            NoEmptyLineBefore  = $false
        }

        PSPlaceOpenBrace = @{
            Enable             = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $true
            OnSameLine         = $true
        }

        PSProvideCommentHelp = @{
            Enable                  = $true
            BlockComment            = $true
            ExportedOnly            = $true
            # Valid values:
            # - before
            # - begin
            # - end
            Placement               = 'begin'
            VSCodeSnippetCorrection = $false
        }

        PSReviewUnusedParameter = @{
            # ForEach-Object and Where-Object are always included
            CommandsToTraverse = @()
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            # Valid values:
            # - space
            # - tab
            Kind                = 'space'
            # Valid values:
            # - None
            # - NoIndentation
            # - IncreaseIndentationForFirstPipeline
            # - IncreaseIndentationAfterEveryPipeline
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentParameterSetName = @{
            Enable = $true
        }

        PSUseConsistentParametersKind = @{
            Enable         = $true
            # Valid values:
            # - Inline
            # - ParamBlock
            ParametersKind = 'ParamBlock'
        }

        PSUseConsistentWhitespace = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckParameter                          = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSUseConstrainedLanguageMode = @{
            Enable           = $false
            IgnoreSignatures = $true
        }

        PSUseCorrectCasing = @{
            Enable        = $true
            CheckCommands = $true
            CheckKeyword  = $false
            CheckOperator = $true
        }

        PSUseSingleValueFromPipelineParameter = @{
            Enable = $true
        }

        PSUseSingularNouns = @{
            Enable        = $true
            # If unset, defaults to: Data, Windows
            NounAllowList = @()
        }
    }
}
