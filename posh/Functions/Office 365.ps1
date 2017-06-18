Function Connect-Office365Services {
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Credential()][pscredential]$Credential,

        [Parameter(Mandatory)]
        [String]$SharePointTenantName,

        [String]$SccCmdletsPrefix='Scc'
    )

    Write-Host -ForegroundColor Green -Object 'Connecting to Exchange Online ...'
    Connect-ExchangeOnline -Credential $Credential

    Write-Host -ForegroundColor Green -Object 'Connecting to SharePoint Online ...'
    Connect-SharePointOnline -Credential $Credential -TenantName $SharePointTenantName

    Write-Host -ForegroundColor Green -Object 'Connecting to Skype for Business Online ...'
    Connect-SkypeForBusinessOnline -Credential $Credential

    Write-Host -ForegroundColor Green -Object 'Connecting to Security & Compliance Center ...'
    Connect-Office365SecurityAndComplianceCenter -Credential $Credential -CmdletsPrefix $SccCmdletsPrefix

    Write-Host -ForegroundColor Green -Object 'Connecting to Centralized Deployment ...'
    Connect-Office365CentralizedDeployment -Credential $Credential
}


Function Connect-ExchangeOnline {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='Standard',Mandatory)]
        [System.Management.Automation.Credential()][pscredential]$Credential,

        [Parameter(ParameterSetName='MFA')]
        [String]$UserPrincipalName
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        if (!(Get-Command -Name Connect-EXOPSSession -ErrorAction SilentlyContinue)) {
            $ExoPowerShellModule = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Apps\2.0\TD1HV8YN.61O\1EP3V7G6.KPP\micr..tion_c3bce3770c238a49_0010.0000_90fa60bba125a33a\CreateExoPSSession.ps1'
            if (Test-Path -Path $ExoPowerShellModule -PathType Leaf) {
                . $ExoPowerShellModule
            } else {
                throw 'Required module not available: Microsoft.Exchange.Management.ExoPowershellModule'
            }
        }
    }

    Write-Verbose -Message 'Connecting to Exchange Online ...'
    if ($PSCmdlet.ParameterSetName -eq 'Standard') {
        $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $Credential -Authentication 'Basic' -AllowRedirection
        Import-PSSession -Session $ExchangeOnline -DisableNameChecking
    } else {
        Connect-EXOPSSession @PSBoundParameters
    }
}


Function Connect-SharePointOnline {
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Credential()][pscredential]$Credential,

        [Parameter(Mandatory)]
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
    Param(
        [Parameter(Mandatory)]
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
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Credential()][pscredential]$Credential,

        [String]$CmdletsPrefix='Scc'
    )

    Write-Verbose -Message 'Connecting to Office 365 Security and Compliance Center ...'
    $Office365SCC = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://ps.compliance.protection.outlook.com/powershell-liveid/' -Credential $Credential -Authentication 'Basic' -AllowRedirection
    Import-PSSession -Session $Office365SCC -Prefix $CmdletsPrefix
}


Function Connect-Office365CentralizedDeployment {
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Credential()][pscredential]$Credential
    )

    if (!(Get-Module -Name OrganizationAddInService -ListAvailable)) {
        throw 'Required module not available: OrganizationAddInService'
    }

    Write-Verbose -Message 'Connecting to Office 365 Centralized Deployment ...'
    Import-Module -Name OrganizationAddInService
    Connect-OrganizationAddInService @PSBoundParameters
}
