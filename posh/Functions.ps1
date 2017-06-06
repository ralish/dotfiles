Function Connect-Office365Services {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Credential()][pscredential]$Credential,

        [Parameter(Mandatory=$true)]
        [String]$SharePointTenantName,

        [String]$SccCmdletsPrefix='Scc'
    )

    Write-Host -Object 'Connecting to Exchange Online ...' -ForegroundColor Green
    Connect-ExchangeOnline -Credential $Credential

    Write-Host -Object 'Connecting to SharePoint Online ...' -ForegroundColor Green
    Connect-SharePointOnline -Credential $Credential -TenantName $SharePointTenantName

    Write-Host -Object 'Connecting to Skype for Business Online ...' -ForegroundColor Green
    Connect-SkypeForBusinessOnline -Credential $Credential

    Write-Host -Object 'Connecting to Security & Compliance Center ...' -ForegroundColor Green
    Connect-Office365SecurityAndComplianceCenter -Credential $Credential -CmdletsPrefix $SccCmdletsPrefix

    Write-Host -Object 'Connecting to Centralized Deployment ...' -ForegroundColor Green
    Connect-Office365CentralizedDeployment -Credential $Credential
}

Function Connect-MSOnline {
    [CmdletBinding()]
    Param(
        [System.Management.Automation.Credential()][pscredential]$Credential
    )

    if (!(Get-Module -Name MSOnline -ListAvailable)) {
        throw 'Required module not available: MSOnline'
    }

    Write-Verbose -Message 'Connecting to Azure AD (v1) ...'
    Import-Module -Name MSOnline
    Connect-MsolService @PSBoundParameters
}

Function Connect-AzureAD {
    [CmdletBinding()]
    Param(
        [System.Management.Automation.Credential()][pscredential]$Credential
    )

    if (!(Get-Module -Name AzureAD -ListAvailable)) {
        throw 'Required module not available: AzureAD'
    }

    Write-Verbose -Message 'Connecting to Azure AD (v2) ...'
    Import-Module -Name AzureAD
    Azure-AD\Connect-AzureAD @PSBoundParameters
}

Function Connect-ExchangeOnline {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='Standard',Mandatory=$true)]
        [System.Management.Automation.Credential()][pscredential]$Credential,

        [Parameter(ParameterSetName='MFA')]
        [String]$UserPrincipalName
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        $ExoPowerShellModule = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Apps\2.0\TD1HV8YN.61O\1EP3V7G6.KPP\micr..tion_c3bce3770c238a49_0010.0000_90fa60bba125a33a\CreateExoPSSession.ps1'

        if (!(Get-Command -Name Connect-EXOPSSession -ErrorAction SilentlyContinue)) {
            if (Test-Path -Path $ExoPowerShellModule -PathType Leaf) {
                . $ExoPowerShellModule
            } else {
                throw 'Required module not available: Microsoft.Exchange.Management.ExoPowershellModule'
            }
        }
    }

    Write-Verbose -Message 'Connecting to Exchange Online ...'
    if ($PSCmdlet.ParameterSetName -eq 'Standard') {
        $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
        Import-PSSession -Session $ExchangeOnline -DisableNameChecking
    } else {
        Connect-EXOPSSession @PSBoundParameters
    }
}

Function Connect-SharePointOnline {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Credential()][pscredential]$Credential,

        [Parameter(Mandatory=$true)]
        [String]$TenantName
    )

    if (!(Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
        throw 'Required module not available: Microsoft.Online.SharePoint.PowerShell'
    }

    Write-Verbose -Message 'Connecting to SharePoint Online ...'
    Import-Module -Name Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
    $SPOUrl = 'https://{0}-admin.sharepoint.com' -f $TenantName
    Connect-SPOService -Url $SPOUrl -Credential $Credential
}

Function Connect-SkypeForBusinessOnline {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Credential()][pscredential]$Credential
    )

    if (!(Get-Module -Name SkypeOnlineConnector -ListAvailable)) {
        throw 'Required module not available: SkypeOnlineConnector'
    }

    Write-Verbose -Message 'Connecting to Skype for Business Online ...'
    Import-Module -Name SkypeOnlineConnector
    $SkypeForBusinessOnline = New-CsOnlineSession @PSBoundParameters
    Import-PSSession -Session $SkypeForBusinessOnline
}

Function Connect-Office365SecurityAndComplianceCenter {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Credential()][pscredential]$Credential,

        [String]$CmdletsPrefix='Scc'
    )

    Write-Verbose -Message 'Connecting to Office 365 Security and Compliance Center ...'
    $Office365SCC = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://ps.compliance.protection.outlook.com/powershell-liveid/' -Credential $Credential -Authentication 'Basic' -AllowRedirection
    Import-PSSession -Session $Office365SCC -Prefix $CmdletsPrefix
}

Function Connect-Office365CentralizedDeployment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Credential()][pscredential]$Credential
    )

    if (!(Get-Module -Name OrganizationAddInService -ListAvailable)) {
        throw 'Required module not available: OrganizationAddInService'
    }

    Write-Verbose -Message 'Connecting to Office 365 Centralized Deployment ...'
    Import-Module -Name OrganizationAddInService
    Connect-OrganizationAddInService @PSBoundParameters
}

# Convert a string to the Base64 form suitable for usage with PowerShell's "-EncodedCommand" parameter
Function ConvertTo-PoShBase64 {
    Param(
        [Parameter(Position=1,Mandatory=$true)]
        [String]$String
    )

    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}

# Convert a string from the Base64 form suitable for usage with PowerShell's "-EncodedCommand" parameter
Function ConvertFrom-PoShBase64 {
    Param(
        [Parameter(Position=1,Mandatory=$true)]
        [String]$String
    )

    [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($String))
}

# Neatly print out all users with UIDs (uses RFC2307 schema extensions)
Function Get-ADUserUID {
    Get-ADUser -Filter { uidNumber -ge 10000 } -Properties uidNumber, sAMAccountName, name, mail, loginShell, unixHomeDirectory, gidNumber `
     | Sort-Object -Property uidNumber `
     | Format-Table -Property uidNumber, sAMAccountName, name, mail, loginShell, unixHomeDirectory, gidNumber
}

# Neatly print out all groups with GIDs (uses RFC2307 schema extensions)
Function Get-ADGroupGID {
    Get-ADGroup -Filter { gidNumber -ge 10000 } -Properties gidNumber, sAMAccountName, memberUid `
     | Sort-Object -Property gidNumber `
     | Format-Table -Property gidNumber, sAMAccountName, memberUid
}

# Watch a nominated Windows Event Log (in a similar fashion to "tail")
# Slightly improved from: http://stackoverflow.com/questions/15262196/powershell-tail-windows-event-log-is-it-possible
Function Get-EventLogTail {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$EventLog
    )

    $idx1 = (Get-EventLog -LogName $EventLog -Newest 1).Index
    do {
        Start-Sleep -Seconds 1
        $idx2 = (Get-EventLog -LogName $EventLog -Newest 1).Index
        Get-EventLog -LogName $EventLog -Newest ($idx2 - $idx1) | Sort-Object -Property Index
        $idx1 = $idx2
    } while ($true)
}

# Find Office 365 users which have one or more disabled licenced services
Function Get-Office365UsersWithDisabledServices {
    $Users = Get-MsolUser | Where-Object { $_.IsLicensed -eq $true}
    foreach ($User in $Users) {
        $DisabledServices = @()
        $LicencedServices = $User.Licenses.ServiceStatus

        foreach ($Service in $LicencedServices) {
            if ($Service.ProvisioningStatus -eq 'Disabled') {
                $DisabledServices += $Service
            }
        }

        if ($DisabledServices.Count -gt 0) {
            Write-Output -InputObject ('{0} has the following disabled services:' -f $User.DisplayName)
            $DisabledServices
            Write-Output -InputObject ''
        }
    }
}

# The MKLINK command is actually part of the Command Processor (cmd.exe)
# So we have a quick and dirty function below to invoke it via PowerShell
Function mklink {
    & "$env:ComSpec" /c mklink $args
}
