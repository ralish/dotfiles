# PSScriptAnalyzer settings
#
# Last reviewed release: v1.21.0

@{
    IncludeRules = @('*')

    ExcludeRules = @(
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingWriteHost',
        # Broken with child scopes pending fix (GH #1472)
        'PSReviewUnusedParameter',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns'
    )

    Rules = @{
        # Compatibility rules
        PSUseCompatibleSyntax = @{
            Enable         = $true
            # Only major versions from v3.0 are supported
            TargetVersions = @('5.0', '7.0')
        }

        # General rules
        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSAvoidLongLines = @{
            Enable            = $false
            MaximumLineLength = 119
        }

        PSAvoidUsingCmdletAliases = @{
            allowlist = @('%', '?')
        }

        PSAvoidUsingPositionalParameters = @{
            Enable           = $true
            CommandAllowList = @('az')
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
    }
}
