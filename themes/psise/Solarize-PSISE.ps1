<#
From http://ethanschoonover.com/solarized#usage-development
Base colors:
base03    #002b36
base02    #073642
base01    #586e75
base00    #657b83
base0     #839496
base1     #93a1a1
base2     #eee8d5
base3     #fdf6e3

The base colors are chosen depending upon the light or dark theme.
base*3    background
base*2    background highlights
base*1    optional emphasized content; comments/ secondary content
base*0    body text/ default code/ primary content

Dark theme uses base0[1-3],base[0-1].
  Background is base03. Highlights are base02. Comments are base01. Body text is base0. Emphasized text is base1.

Light theme uses base[1-3],base0[0-1].
  Background is base3. Highlights are base2. Comments are base1. Body text is base00. Emphasized test is base01.

Others colors as follows. These are common to both themes.
yellow    #b58900
orange    #cb4b16
red       #dc322f
magenta   #d33682
violet    #6c71c4
blue      #268bd2
cyan      #2aa198
green     #859900

In PowerShell ISE, token colors can be set via $psISE.Options.TokenColors.
Pane colors can be set via $psISE.Options.CommandPaneBackgroundColor etc.
See http://technet.microsoft.com/en-us/library/dd819482.aspx
#>

<#
.SYNOPSIS
Sets the colors of the PowerShell ISE from the Solarized color palette.

.DESCRIPTION
Solarized is a sixteen color palette (eight monotones, eight accent colors) designed for use with terminal and GUI applications. You can read more about it at http://ethanschoonover.com/solarized.

This script sets the colors of your PowerShell ISE from the Solarized color palette. Without any switches it sets colors from the light palette. With the correct it sets colors from the dark palette.

It works with both PowerShell 2.0 and 3.0 ISE. Only the Script pane colors can be changed between light and dark; the Output/ Command/ Console pane colors are always set to dark.

.PARAMETER Dark
If specified, colors are set from the dark palette.

This parameter is optional. If not specified colors are set from the light palette.

.PARAMETER FontSize
If specified, sets the font size.

This parameter is optional. If not specified size 10 is used.

.EXAMPLE
Solarize-PSISE -Dark

To set colors from the dark palette.

.EXAMPLE
Solarize-PSISE

To set colors from the light palette.

.LINK
http://ethanschoonover.com/solarized

.LINK
https://github.com/rakheshster/Solarize-PSISE

.NOTES
Future versions should allow users to specify Font Name via parameters.

Future version could also include a switch to set the Output/ Command/ Console pane colors along with Script pane colors.
#>

# Defining a switch parameter which lets you flick between dark and light themes
# If $Dark is set the dark theme is used; else it's the light theme.
param(
  [parameter(Mandatory=$false)]
  [Switch]
  $Dark,

  [parameter(Mandatory=$false)]
  [int32]
  $FontSize = 10
)

# Global Definitions
## Variables for the colors codes
$base03   = "#002b36"
$base02   = "#073642"
$base01   = "#586e75"
$base00   = "#657b83"
$base0    = "#839496"
$base1    = "#93a1a1"
$base2    = "#eee8d5"
$base3    = "#fdf6e3"
$yellow   = "#b58900"
$orange   = "#cb4b16"
$red      = "#dc322f"
$magenta  = "#d33682"
$violet   = "#6c71c4"
$blue     = "#268bd2"
$cyan     = "#2aa198"
$green    = "#859900"

$bgCol = if ($Dark) { $base03 } else { $base3 }
$primaryCol = if ($Dark) { $base0 } else { $base00 }
$emphasizeCol = if ($Dark) { $base1 } else { $base01 }
$secondaryCol = if ($Dark) { $base01 } else { $base1 }

## Variables for the fonts
## These are the default PowerShell font and size; change if you want to.
## !!TODO!! allow users to specify this on the command line? Obviously check with the installed fonts to validate.
$Font     = "Lucida Console"

# The actual action starts here.
# The Script pane is common to both PowerShell 2.0 and 3.0 ISE. Defining its colors & fonts here.
$psISE.Options.ScriptPaneBackgroundColor = $bgCol
$psISE.Options.ScriptPaneForegroundColor = $primaryCol

$psISE.Options.FontName = $Font
$psISE.Options.FontSize = $FontSize

# Attributes are items like [CmdletBinding()], [Parameter] etc in function definitions.
$psISE.Options.TokenColors.Item("Attribute") = $yellow

# Cmdlets, their arguments & parameters.
$psISE.Options.TokenColors.Item("Command") = $emphasizeCol
$psISE.Options.TokenColors.Item("CommandArgument") = $blue
$psISE.Options.TokenColors.Item("CommandParameter") = $red

# Comments.
$psISE.Options.TokenColors.Item("Comment") = $secondaryCol

# Brackets etc.
$psISE.Options.TokenColors.Item("GroupEnd") = $emphasizeCol
$psISE.Options.TokenColors.Item("GroupStart") = $emphasizeCol

# Keywords (if, while, etc).
$psISE.Options.TokenColors.Item("Keyword") = $green

# Not really sure what this is, so setting this to the default color.
$psISE.Options.TokenColors.Item("LineContinuation") = $primaryCol

# Not really sure what this is, but since it's a label I'm setting it to the highlight color.
$psISE.Options.TokenColors.Item("LoopLabel") = $emphasizeCol

# Members.
$psISE.Options.TokenColors.Item("Member") = $primaryCol

# Not really sure what this is, so setting this to the default color.
$psISE.Options.TokenColors.Item("NewLine") = $primaryCol

# Numbers (even as array indexes).
$psISE.Options.TokenColors.Item("Number") = $cyan

# Operators (+, += etc).
$psISE.Options.TokenColors.Item("Operator") = $primaryCol

# Not really sure what this is, so setting this to the default color.
$psISE.Options.TokenColors.Item("Position") = $primaryCol

# Statement separators (semicolon etc).
$psISE.Options.TokenColors.Item("StatementSeparator") = $emphasizeCol

# String.
$psISE.Options.TokenColors.Item("String") = $cyan

# Type defintions ([int32] etc).
$psISE.Options.TokenColors.Item("Type") = $violet

# Unknown items (I this is the color you will see while typing and before it's actually colored.
$psISE.Options.TokenColors.Item("Unknown") = $primaryCol

# Variables.
$psISE.Options.TokenColors.Item("Variable") = $orange

# Setting the background color of various messages to that of highlighted text of dark theme.
$psISE.Options.ErrorBackgroundColor = $base02
$psISE.Options.WarningBackgroundColor = $base02
$psISE.Options.VerboseBackgroundColor = $base02
$psISE.Options.DebugBackgroundColor = $base02

# I read somewhere that error messages are better off being in a different color than $red so as to not put you off.
$psISE.Options.ErrorForegroundColor = $green
$psISE.Options.WarningForegroundColor = $orange
$psISE.Options.VerboseForegroundColor = $yellow
$psISE.Options.DebugForegroundColor = $blue

# Now for the PowerShell ISE version specific stuff
if ($PSVersionTable.PSVersion.Major -eq 2) {
  # PowerShell 2.0 ISE specific stuff go here. Command pane & Output pane colors.
  # Command pane background colors.
  # Can't set the foreground color as that's taken from the Script pane foreground color.
  $psISE.Options.CommandPaneBackgroundColor = $bgCol

  # Output pane colors.
  $psISE.Options.OutputPaneBackgroundColor = $psISE.Options.OutputPaneTextBackgroundColor = $base03
  $psISE.Options.OutputPaneForegroundColor = $base1
} else {
  # PowerShell 3.0 ISE and later specific stuff go here. No Command pane & Output pane.
  # Has a Console pane that is essentially the Command & Output panes combined and supports token colors! W00t!

  # Console pane colors.
  $psISE.Options.ConsolePaneBackgroundColor = $psISE.Options.ConsolePaneTextBackgroundColor = $bgCol
  $psISE.Options.ConsolePaneForegroundColor = $primaryCol

  # Token colors in the console pane. Skipping comments as these are same as the token definitions in the Script pane (defined above).
  $psISE.Options.ConsoleTokenColors.Item("Attribute") = $yellow
  $psISE.Options.ConsoleTokenColors.Item("Command") = $emphasizeCol
  $psISE.Options.ConsoleTokenColors.Item("CommandArgument") = $blue
  $psISE.Options.ConsoleTokenColors.Item("CommandParameter") = $red
  $psISE.Options.ConsoleTokenColors.Item("Comment") = $secondaryCol
  $psISE.Options.ConsoleTokenColors.Item("GroupEnd") = $emphasizeCol
  $psISE.Options.ConsoleTokenColors.Item("GroupStart") = $emphasizeCol
  $psISE.Options.ConsoleTokenColors.Item("Keyword") = $green
  $psISE.Options.ConsoleTokenColors.Item("LineContinuation") = $primaryCol
  $psISE.Options.ConsoleTokenColors.Item("LoopLabel") = $emphasizeCol
  $psISE.Options.ConsoleTokenColors.Item("Member") = $primaryCol
  $psISE.Options.ConsoleTokenColors.Item("NewLine") = $primaryCol
  $psISE.Options.ConsoleTokenColors.Item("Number") = $cyan
  $psISE.Options.ConsoleTokenColors.Item("Operator") = $primaryCol
  $psISE.Options.ConsoleTokenColors.Item("Position") = $primaryCol
  $psISE.Options.ConsoleTokenColors.Item("StatementSeparator") = $emphasizeCol
  $psISE.Options.ConsoleTokenColors.Item("String") = $cyan
  $psISE.Options.ConsoleTokenColors.Item("Type") = $violet
  $psISE.Options.ConsoleTokenColors.Item("Unknown") = $primaryCol
  $psISE.Options.ConsoleTokenColors.Item("Variable") = $orange

  # When you hover over the outlining lines there's a brief flash of white background in the script pane
  # I don't know any workaround so I disable Outlining altogether.
  $psISE.Options.ShowOutlining = $false
}

Write-Verbose "All done!"
