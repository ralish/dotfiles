Function Connect-Office365Services {
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$SharePointTenantName,

        [ValidateNotNullOrEmpty()]
        [String]$SccCmdletsPrefix='Scc'
    )

    Write-Host -ForegroundColor Green -Object 'Connecting to Exchange Online ...'
    Connect-ExchangeOnline -Credential $Credential

    Write-Host -ForegroundColor Green -Object 'Connecting to SharePoint Online ...'
    Connect-SharePointOnline -TenantName $SharePointTenantName -Credential $Credential

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
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$UserPrincipalName,

        [Parameter(ParameterSetName='Standard',Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        if (!(Get-Command -Name Connect-EXOPSSession -ErrorAction Ignore)) {
            $ClickOnceAppsPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Apps\2.0'
            $ExoPowerShellModule = Get-ChildItem -Path $ClickOnceAppsPath -Recurse -Include 'Microsoft.Exchange.Management.ExoPowershellModule.manifest'
            $ExoPowerShellModuleDll = Join-Path -Path $ExoPowerShellModule.Directory.FullName -ChildPath 'Microsoft.Exchange.Management.ExoPowerShellModule.dll'
            $ExoPowerShellModulePs1 = Join-Path -Path $ExoPowerShellModule.Directory.FullName -ChildPath 'CreateExoPSSession.ps1'

            if ($ExoPowerShellModule) {
                Import-Module -FullyQualifiedName $ExoPowerShellModuleDll
                . $ExoPowerShellModulePs1
            } else {
                throw 'Required module not available: Microsoft.Exchange.Management.ExoPowershellModule'
            }
        }
    }

    Write-Verbose -Message 'Connecting to Exchange Online ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-EXOPSSession @PSBoundParameters
    } else {
        # Workaround for a weird bug
        # See: https://stackoverflow.com/questions/41596482/import-pssession-error-when-called-in-a-function
        Remove-Variable -Name UserPrincipalName

        $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $Credential -Authentication 'Basic' -AllowRedirection
        Import-PSSession -Session $ExchangeOnline -DisableNameChecking
    }
}


Function Connect-SharePointOnline {
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$TenantName,

        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (!(Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
        throw 'Required module not available: Microsoft.Online.SharePoint.PowerShell'
    }

    Write-Verbose -Message 'Connecting to SharePoint Online ...'
    $SPOUrl = 'https://{0}-admin.sharepoint.com' -f $TenantName
    if ($Credential) {
        Connect-SPOService -Url $SPOUrl -Credential $Credential
    } else {
        Connect-SPOService -Url $SPOUrl
    }
}


Function Connect-SkypeForBusinessOnline {
    [CmdletBinding()]
    Param(
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (!(Get-Module -Name SkypeOnlineConnector -ListAvailable)) {
        throw 'Required module not available: SkypeOnlineConnector'
    }

    Write-Verbose -Message 'Connecting to Skype for Business Online ...'
    $SkypeForBusinessOnline = New-CsOnlineSession @PSBoundParameters
    Import-PSSession -Session $SkypeForBusinessOnline
}


Function Connect-Office365SecurityAndComplianceCenter {
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential,

        [ValidateNotNullOrEmpty()]
        [String]$CmdletsPrefix='Scc'
    )

    Write-Verbose -Message 'Connecting to Office 365 Security and Compliance Center ...'
    $Office365SCC = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://ps.compliance.protection.outlook.com/powershell-liveid/' -Credential $Credential -Authentication 'Basic' -AllowRedirection
    Import-PSSession -Session $Office365SCC -Prefix $CmdletsPrefix
}


Function Connect-Office365CentralizedDeployment {
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (!(Get-Module -Name OrganizationAddInService -ListAvailable)) {
        throw 'Required module not available: OrganizationAddInService'
    }

    Write-Verbose -Message 'Connecting to Office 365 Centralized Deployment ...'
    Connect-OrganizationAddInService @PSBoundParameters
}
