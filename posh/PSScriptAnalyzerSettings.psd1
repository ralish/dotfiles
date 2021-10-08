@{
    IncludeRules = @('*')

    ExcludeRules = @(
        # Broken with child scopes pending fix (GH PR #1489)
        'PSReviewUnusedParameter',
        'PSUseOutputTypeCorrectly'
    )

    Rules        = @{
        # Compatibility rules
        PSAvoidOverwritingBuiltInCmdlets = @{
            PowerShellVersion = @()
        }

        PSUseCompatibleCmdlets           = @{
            compatibility = @()
        }

        PSUseCompatibleCommands          = @{
            Enable         = $false
            ProfileDirPath = ''
            TargetProfiles = @()
            IgnoreCommands = @()
        }

        PSUseCompatibleSyntax            = @{
            Enable         = $false
            # Only major versions from v3.0 are supported
            TargetVersions = @()
        }

        PSUseCompatibleTypes             = @{
            Enable         = $false
            ProfileDirPath = ''
            TargetProfiles = @()
            IgnoreTypes    = @()
        }

        # General rules
        PSAlignAssignmentStatement       = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSAvoidLongLines                 = @{
            Enable            = $false
            MaximumLineLength = 120
        }

        PSAvoidUsingCmdletAliases        = @{
            allowlist = @()
        }

        PSPlaceCloseBrace                = @{
            Enable             = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $false
            NoEmptyLineBefore  = $false
        }

        PSPlaceOpenBrace                 = @{
            Enable             = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $true
            OnSameLine         = $true
        }

        PSProvideCommentHelp             = @{
            Enable                  = $true
            BlockComment            = $true
            ExportedOnly            = $true
            Placement               = 'begin'
            VSCodeSnippetCorrection = $false
        }

        PSUseConsistentIndentation       = @{
            Enable              = $true
            IndentationSize     = 4
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace        = @{
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
