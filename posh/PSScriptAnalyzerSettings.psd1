# PSScriptAnalyzer settings
#
# Last reviewed release: v1.21.0

@{
    IncludeRules = @('*')

    ExcludeRules = @(
        # Broken with child scopes pending fix (GH #1472)
        'PSReviewUnusedParameter',
        'PSUseOutputTypeCorrectly'
    )

    Rules = @{
        # Compatibility rules
        PSAvoidOverwritingBuiltInCmdlets = @{
            Enable            = $false
            PowerShellVersion = @()
        }

        PSUseCompatibleCmdlets = @{
            compatibility = @()
        }

        PSUseCompatibleCommands = @{
            Enable         = $false
            ProfileDirPath = ''
            TargetProfiles = @()
            IgnoreCommands = @()
        }

        PSUseCompatibleSyntax = @{
            Enable         = $false
            # Only major versions from v3.0 are supported
            TargetVersions = @()
        }

        PSUseCompatibleTypes = @{
            Enable         = $false
            ProfileDirPath = ''
            TargetProfiles = @()
            IgnoreTypes    = @()
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
            allowlist = @()
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
