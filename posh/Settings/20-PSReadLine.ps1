# PSReadLine
# https://learn.microsoft.com/en-au/powershell/module/psreadline/
# https://github.com/PowerShell/PSReadLine

$DotFilesSection = @{
    Type            = 'Settings'
    Name            = 'PSReadLine'
    Module          = 'PSReadLine'
    ModuleOperation = 'Import'
    PwshHostName    = 'ConsoleHost'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Setup `PSReadLine` configuration
Function Initialize-PSReadLine {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Disable terminal bell
    Set-PSReadLineOption -BellStyle 'None'

    # Don't store duplicate history entries
    Set-PSReadLineOption -HistoryNoDuplicates

    # Move the cursor to end of line when cycling through history
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd

    # Command-line completion prediction sources
    #
    # `PSReadLine` picks a sensible default since v2.2.6
    # https://github.com/PowerShell/PSReadLine/pull/3351
    #Set-PSReadLineOption -PredictionSource 'HistoryAndPlugin'

    # Display predictions as a list under the prompt
    Set-PSReadLineOption -PredictionViewStyle 'ListView'

    if (Test-IsUnix) {
        # The default for non-Windows platforms is Emacs
        Set-PSReadLineOption -EditMode 'Vi'

        # We use the Solarized Dark colour scheme for WSL sessions in Windows
        # Terminal. Unfortunately, some `PSReadLine` colours are near invisible
        # when used with this colour scheme. Switch the affected colours to
        # something more visible.
        #
        # References:
        # - https://github.com/microsoft/terminal/pull/6617
        # - https://github.com/microsoft/terminal/pull/6618
        # - https://github.com/microsoft/terminal/pull/6489
        if ($Env:WT_SESSION) {
            Set-PSReadLineOption -Colors @{
                Operator  = [ConsoleColor]::Magenta
                Parameter = [ConsoleColor]::Magenta
            }
        }
    }

    # Menu style command completion
    Set-PSReadLineKeyHandler -Key 'Tab' -Function 'MenuComplete'

    # Search the command history based on any already entered text
    Set-PSReadLineKeyHandler -Key 'UpArrow' -Function 'HistorySearchBackward'
    Set-PSReadLineKeyHandler -Key 'DownArrow' -Function 'HistorySearchForward'

    # Setup our custom key handlers
    Set-PSReadLineKeyHandlerCommandHelpWindow
    Set-PSReadLineKeyHandlerExpandAliases
    Set-PSReadLineKeyHandlerInsertPairedBraces
    Set-PSReadLineKeyHandlerInsertPairedParenthesis
    Set-PSReadLineKeyHandlerSmartCloseBraces

    # Clean-up the key handler setup functions
    Remove-Item -LiteralPath @(
        'Function:\Set-PSReadLineKeyHandlerCommandHelpWindow'
        'Function:\Set-PSReadLineKeyHandlerExpandAliases'
        'Function:\Set-PSReadLineKeyHandlerInsertPairedBraces'
        'Function:\Set-PSReadLineKeyHandlerInsertPairedParenthesis'
        'Function:\Set-PSReadLineKeyHandlerSmartCloseBraces'
    )
}

# Show help for the command at the cursor in a new window
#
# From the PSReadLine sample profile with minor clean-up:
# https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1
Function Set-PSReadLineKeyHandlerCommandHelpWindow {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $KeyHandlerScript = {
        Param($Key, $Arg)

        $Ast = $Tokens = $Errors = $Cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([Ref]$Ast, [Ref]$Tokens, [Ref]$Errors, [Ref]$Cursor)

        $CommandAstFind = {
            $Node = $args[0]
            $Node -is [Management.Automation.Language.CommandAst] -and
            $Node.Extent.StartOffset -le $Cursor -and
            $Node.Extent.EndOffset -ge $Cursor
        }
        $CommandAst = $Ast.FindAll($CommandAstFind, $true) | Select-Object -Last 1
        if (!$CommandAst) { return }

        $CommandName = $CommandAst.GetCommandName()
        if (!$CommandName) { return }

        $Command = $ExecutionContext.InvokeCommand.GetCommand($CommandName, 'All')
        if ($Command -is [Management.Automation.AliasInfo]) {
            $CommandName = $Command.ResolvedCommandName
        }

        if ($CommandName) {
            Get-Help -Name $CommandName -ShowWindow
        }
    }

    $KeyHandlerParams = @{
        Chord            = 'Ctrl+F1'
        BriefDescription = 'CommandHelpWindow'
        LongDescription  = 'Show help for the command at the cursor in a new window'
        ScriptBlock      = $KeyHandlerScript
    }

    Set-PSReadLineKeyHandler @KeyHandlerParams
}

# Expand all aliases for the current command
#
# From the PSReadLine sample profile with minor clean-up:
# https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1
Function Set-PSReadLineKeyHandlerExpandAliases {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $KeyHandlerScript = {
        Param($Key, $Arg)

        $Ast = $Tokens = $Errors = $Cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([Ref]$Ast, [Ref]$Tokens, [Ref]$Errors, [Ref]$Cursor)

        $StartAdjustment = 0
        foreach ($Token in $Tokens) {
            if (!($Token.TokenFlags -band [Management.Automation.Language.TokenFlags]::CommandName)) { continue }

            $Alias = $ExecutionContext.InvokeCommand.GetCommand($Token.Extent.Text, 'Alias')
            if (!$Alias) { continue }

            $ResolvedCommand = $Alias.ResolvedCommandName
            if (!$ResolvedCommand) { continue }

            $Extent = $Token.Extent
            $Length = $Extent.EndOffset - $Extent.StartOffset
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                $Extent.StartOffset + $StartAdjustment,
                $Length,
                $ResolvedCommand)

            # Our copy of the tokens won't have been updated, so we need to
            # adjust by the difference in length.
            $StartAdjustment += ($ResolvedCommand.Length - $Length)
        }
    }

    $KeyHandlerParams = @{
        Chord            = 'Alt+%'
        BriefDescription = 'ExpandAliases'
        LongDescription  = 'Expand all aliases for the current command'
        ScriptBlock      = $KeyHandlerScript
    }

    Set-PSReadLineKeyHandler @KeyHandlerParams
}

# Insert a matching closing brace
#
# From the PSReadLine sample profile with minor clean-up:
# https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1
Function Set-PSReadLineKeyHandlerInsertPairedBraces {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $KeyHandlerScript = {
        Param($Key, $Arg)

        $CloseChar = switch ($Key.KeyChar) {
            '(' { [Char]')'; break }
            '{' { [Char]'}'; break }
            '[' { [Char]']'; break }
        }

        $Line = $Cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([Ref]$Line, [Ref]$Cursor)

        $SelectionStart = $SelectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([Ref]$SelectionStart, [Ref]$SelectionLength)

        if ($selectionStart -eq -1) {
            # No text is selected -> insert a pair
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($Key.KeyChar)$CloseChar")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 1)
        } else {
            # Text is selected -> wrap it in brackets
            $SelectionText = $Line.SubString($SelectionStart, $SelectionLength)
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($SelectionStart, $SelectionLength, $Key.KeyChar + $SelectionText + $CloseChar)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($SelectionStart + $SelectionLength + 2)
        }
    }

    $KeyHandlerParams = @{
        Chord            = '(', '{', '['
        BriefDescription = 'InsertPairedBraces'
        LongDescription  = 'Insert a matching closing brace'
        ScriptBlock      = $KeyHandlerScript
    }

    Set-PSReadLineKeyHandler @KeyHandlerParams
}

# Insert parenthesis around the selection or the entire line
#
# From the PSReadLine sample profile with minor clean-up:
# https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1
Function Set-PSReadLineKeyHandlerInsertPairedParenthesis {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $KeyHandlerScript = {
        Param($Key, $Arg)

        $Line = $Cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([Ref]$Line, [Ref]$Cursor)

        $SelectionStart = $SelectionLength = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([Ref]$SelectionStart, [Ref]$SelectionLength)

        if ($SelectionStart -eq -1) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $Line.Length, "(${Line})")
            [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
        } else {
            $SelectionText = $Line.SubString($SelectionStart, $SelectionLength)
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($SelectionStart, $SelectionLength, "(${SelectionText})")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($SelectionStart + $SelectionLength + 2)
        }
    }

    $KeyHandlerParams = @{
        Chord            = 'Alt+('
        BriefDescription = 'InsertPairedParenthesis'
        LongDescription  = 'Insert parenthesis around the selection or the entire line'
        ScriptBlock      = $KeyHandlerScript
    }

    Set-PSReadLineKeyHandler @KeyHandlerParams
}

# Insert a closing brace or skip over it
#
# From the PSReadLine sample profile with minor clean-up:
# https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1
Function Set-PSReadLineKeyHandlerSmartCloseBraces {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    $KeyHandlerScript = {
        Param($Key, $Arg)

        $Line = $Cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([Ref]$Line, [Ref]$Cursor)

        if ($Line[$Cursor] -eq $Key.KeyChar) {
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($Cursor + 1)
        } else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($Key.KeyChar)")
        }
    }

    $KeyHandlerParams = @{
        Chord            = ')', '}', ']'
        BriefDescription = 'SmartCloseBraces'
        LongDescription  = 'Insert a closing brace or skip over it'
        ScriptBlock      = $KeyHandlerScript
    }

    Set-PSReadLineKeyHandler @KeyHandlerParams
}

Initialize-PSReadLine

Remove-Item -LiteralPath 'Function:\Initialize-PSReadLine'
Complete-DotFilesSection
