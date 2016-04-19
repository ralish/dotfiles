# Solarize-PSISE
## What is it?
Solarized is a sixteen color palette (eight monotones, eight accent colors) designed for use with terminal and gui applications. You can read more about it [here](http://ethanschoonover.com/solarized). 

This is a port of the Solarized color scheme to the PowerShell ISE. 

## What's in the box?
There are two files. 

1. `Solarize-PSISE.ps1` which _when invoked from within PowerShell ISE_ sets the ISE colors from the Solarized palette. Depending on the switches passed to it this script can set colors from the dark or light palette. 

2. `Solarize-PSISE-AddOnMenu.ps1` which, in my opinion, is the script end users should concern themselves with. Invoking this script from within the PowerShell ISE, or adding it to the ISE `$profile`, gets you two menu options under the Add-ons menu item. These menu items let you apply the Solarized palette. If you wish to apply the palette along with creating the menu items it is possible via a switch.

Typing `help` (or `get-help`) followed by the script name will give you more details. In a nutshell `Solarize-PSISE.ps1` has just one switch `-Dark` that determines whether the dark or light palette is used. And `Solarize-PSISE-AddOnMenu.ps1` has two switches: `-Apply` tells it to also apply the palette (light by default), and `-Dark` specifies that the dark palette is to be applied. 

## Installation
1. Copy both scripts to the same location. 

2. Open your PowerShell ISE `$profile`.
  
  If you don't know how, or are unsure whether you have a `$profile` copy-paste the following in the console pane/ command pane in PowerShell ISE and press enter:
  
        if(!(Test-Path $profile)) { New-Item -ItemType File -Path $profile -Force }
        $psISE.CurrentPowerShellTab.Files.Add($profile)
  
  This will create the `$profile` file if it doesn't exist. And then open a new tab with this file loaded. 
  
3. Add a line such as the following to the `$profile` file: `\path\to\files\Solarize-PSISE-AddOnMenu.ps1 -Apply -Dark`

4. Close and open PowerShell ISE. You will notice the dark Solarized palette colors are applied. Also there will be a submenu under Add-ons with two menu items. 
