# PSScriptAnalyzer settings
#
# Last reviewed release: v1.25.0

@{
    IncludeRules = @('*')

    ExcludeRules = @('PSAvoidUsingWriteHost')

    Rules = @{
        # Compatibility rules
        PSAvoidOverwritingBuiltInCmdlets = @{
            Enable            = $true
            PowerShellVersion = @('desktop-5.1.14393.206-windows')
        }

        PSUseCompatibleCommands = @{
            Enable         = $false
            TargetProfiles = @('win-8_x64_10.0.14393.0_5.1.14393.2791_x64_4.0.30319.42000_framework')
            IgnoreCommands = @()
        }

        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.0', '7.0')
        }

        PSUseCompatibleTypes = @{
            Enable         = $true
            TargetProfiles = @('win-8_x64_10.0.14393.0_5.1.14393.2791_x64_4.0.30319.42000_framework')
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

        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }

        PSAvoidUsingCmdletAliases = @{
            allowlist = @()
        }

        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $true
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
            Placement               = 'begin'
            VSCodeSnippetCorrection = $false
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentParameterSetName = @{
            Enable = $true
        }

        PSUseConsistentParametersKind = @{
            Enable         = $true
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

        PSUseCorrectCasing = @{
            Enable        = $true
            CheckCommands = $true
            CheckKeyword  = $false
            CheckOperator = $true
        }

        PSUseSingleValueFromPipelineParameter = @{
            Enable = $true
        }
    }
}
