<#
.SYNOPSIS
Companion script to Solarize-PSISE. Running this script creates Add-on menu entries in PowerShell ISE for applying Solarized palette colors. 

.DESCRIPTION
Companion script to Solarize-PSISE. Running this script creates Add-on menu entries in PowerShell ISE for applying Solarized palette colors. 

Using switches one can also apply the palette.

.PARAMETER Apply
Apply the palette too. By default the light palette is applied.

.PARAMETER Dark
WOrks only if specified along with the Apply. If specified the dark palette is applied instead of the (default) light. 

.PARAMETER FontSize
If specified, sets the font size. 

This parameter is optional. If not specified size 10 is used. 

.EXAMPLE
Solarize-PSISE-AddonMenu

Creates Add-on menu entries. Does not apply the colors. 

.EXAMPLE
Solarize-PSISE-AddonMenu -Apply

Creates Add-on menu entries and applies the light palette to PowerShell ISE. 

.EXAMPLE
Solarize-PSISE-AddonMenu -Apply -Dark

Creates Add-on menu entries and applies the dark palette to PowerShell ISE. 
#>

param(
  [parameter(Mandatory=$false)]
  [Switch]
  $Apply,

  [parameter(Mandatory=$false)]
  [Switch]
  $Dark,

  [parameter(Mandatory=$false)]
  [int32]
  $FontSize = 10
)

# Add a menu entry under the Add-ons menu in PowerShell ISE to apply Solarize colors
# Documentation: http://technet.microsoft.com/en-us/library/dd819494.aspx
$menuName = "Solarize"

# Set the fontsize in a global paramter so we can pass it to the menu creating bit later
$Global:FontSize = $FontSize

# Create a sub-menu if it does not already exist
if (!($psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.DisplayName -contains $menuName)) {
  $SolMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add($menuName,$null,$null)

  # Add entries
  $Global:SolScript = "$(Split-Path (Get-Variable MyInvocation).Value.InvocationName)\Solarize-PSISE.ps1"
  $SolMenu.Submenus.Add("Apply Dark palette",{Invoke-Expression "$Global:SolScript -Dark -FontSize $Global:FontSize"},"Alt+Shift+D") | Out-Null
  $SolMenu.Submenus.Add("Apply Light palette",{Invoke-Expression "$Global:SolScript -FontSize $Global:FontSize"},"Alt+Shift+L") | Out-Null

  # The $Global: bit above took me a while to figure out. During testing this script worked fine without $Global:
  # but when trying live $SolScript would not be visible within the Submenus.Add() scriptblock. I think this is because
  # while testing I was just dot sourcing the script but when trying live I was running it as a script and so 
  # variable scopes came into play. What happens then is that the Submenus.Add() is in a scope of its own - think of it like 
  # a function you are calling - and so if you want it to access a global variable you must define it that way. There's no way
  # of passing a variable to this function, so the only alternative is to use global variables. Hence define the variable as 
  # $Global:whatever and refernce it as $Global:whatever everywhere. 
  # A good demo of Global variables can be found at http://www.dotnetscraps.com/dotnetscraps/post/PowerShell-Tip-15-Global-Variables.aspx
  # Thanks to http://poshcode.org/2247 where I got a hint of the solution from.
  
  Write-Verbose "Created Submenu $menuName and entries"
} `
else { Write-Verbose "Submenu $menuName already exists. Not creating anything" }

# Apply the colors if the users has passed parameters to do so
if ($apply -and $dark) { Write-Verbose "Applying the dark palette, font size $Global:FontSize"; Invoke-Expression "$Global:SolScript -Dark -FontSize $Global:FontSize" }
if ($apply -and !$dark) { Write-Verbose "Applying the light palette, font size $Global:FontSize"; Invoke-Expression "$Global:SolScript -FontSize $Global:FontSize" }