# PSScriptAnalyzer settings
#
# Last reviewed release: v1.22.0

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
            Enable             = $true
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

        PSUseSingularNouns = @{
            Enable        = $true
            # If unset, defaults to: Data, Windows
            NounAllowList = @()
        }
    }
}
