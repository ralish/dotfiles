Function Connect-Office365Services {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName='Standard',Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$SharePointTenantName
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-ExchangeOnline -MfaUsername $MfaUsername
    } else {
        Connect-ExchangeOnline -Credential $Credential
    }

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-SecurityAndComplianceCenter -MfaUsername $MfaUsername
    } else {
        Connect-SecurityAndComplianceCenter -Credential $Credential
    }

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-SharePointOnline -TenantName $SharePointTenantName
    } else {
        Connect-SharePointOnline -TenantName $SharePointTenantName -Credential $Credential
    }

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-SkypeForBusinessOnline -MfaUsername $MfaUsername
    } else {
        Connect-SkypeForBusinessOnline -Credential $Credential
    }

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Write-Warning -Message "Unable to connect to Office 365 Centralized Deployment as it doesn't yet support MFA."
    } else {
        Connect-Office365CentralizedDeployment -Credential $Credential
    }
}

Function Connect-ExchangeOnline {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName='Standard',Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Import-ExoPowershellModule
    }

    Write-Host -ForegroundColor Green -Object 'Connecting to Exchange Online ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-EXOPSSession -UserPrincipalName $MfaUsername
    } else {
        $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
        Import-PSSession -Session $ExchangeOnline
    }
}

Function Connect-Office365CentralizedDeployment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (!(Get-Module -Name OrganizationAddInService -ListAvailable)) {
        throw 'Required module not available: OrganizationAddInService'
    }

    Write-Host -ForegroundColor Green -Object 'Connecting to Office 365 Centralized Deployment ...'
    Connect-OrganizationAddInService @PSBoundParameters
}

Function Connect-SecurityAndComplianceCenter {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName='Standard',Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Import-ExoPowershellModule
    }

    Write-Host -ForegroundColor Green -Object 'Connecting to Security and Compliance Center ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        Connect-IPPSSession -UserPrincipalName $MfaUsername
    } else {
        $SCC = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://ps.compliance.protection.outlook.com/powershell-liveid/' -Credential $Credential -Authentication Basic -AllowRedirection
        Import-PSSession -Session $SCC
    }
}

Function Connect-SharePointOnline {
    [CmdletBinding()]
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

    Write-Host -ForegroundColor Green -Object 'Connecting to SharePoint Online ...'
    $SPOUrl = 'https://{0}-admin.sharepoint.com' -f $TenantName
    if ($Credential) {
        Connect-SPOService -Url $SPOUrl -Credential $Credential
    } else {
        Connect-SPOService -Url $SPOUrl
    }
}

Function Connect-SkypeForBusinessOnline {
    [CmdletBinding(DefaultParameterSetName='MFA')]
    Param(
        [Parameter(ParameterSetName='MFA')]
        [ValidateNotNullOrEmpty()]
        [String]$MfaUsername,

        [Parameter(ParameterSetName='Standard',Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential
    )

    if (!(Get-Module -Name SkypeOnlineConnector -ListAvailable)) {
        throw 'Required module not available: SkypeOnlineConnector'
    }

    # Fix a scope issue due to variable reuse by SkypeOnlineConnector?
    if (-not $PSBoundParameters.ContainsKey('MfaUsername')) {
        Remove-Variable -Name MfaUsername
    }
    if (-not $PSBoundParameters.ContainsKey('Credential')) {
        Remove-Variable -Name Credential
    }

    Write-Host -ForegroundColor Green -Object 'Connecting to Skype for Business Online ...'
    if ($PSCmdlet.ParameterSetName -eq 'MFA') {
        $CsOnlineSession = New-CsOnlineSession -UserName $MfaUsername
    } else {
        $CsOnlineSession = New-CsOnlineSession -Credential $Credential
    }
    Import-PSSession -Session $CsOnlineSession
}

Function Get-UnifiedGroupSummary {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$Groups
    )

    if (!$Groups) {
        Write-Host -ForegroundColor Green -Object 'Retrieving Office 365 groups ...'
        $Groups = Get-UnifiedGroup
    }

    foreach ($Group in $Groups) {
        Write-Host -ForegroundColor Green -Object ('Now processing: {0}' -f $Group.Identity)

        Write-Verbose -Message ('[{0}] Retrieving owners ...' -f $Group.Identity)
        $Owners = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Owners
        if ($Owners) {
            $AllOwners = [String]::Join(', ', ($Owners | Sort-Object))
            Add-Member -InputObject $Group -MemberType NoteProperty -Name Owners -Value $AllOwners -Force
        }

        Write-Verbose -Message ('[{0}] Retrieving members ...' -f $Group.Identity)
        $Members = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Members
        if ($Members) {
            $AllMembers = [String]::Join(', ', ($Members | Sort-Object))
            Add-Member -InputObject $Group -MemberType NoteProperty -Name Members -Value $AllMembers -Force
        }
    }

    return $Groups
}

Function Import-ExoPowershellModule {
    [CmdletBinding()]
    Param()

    if (!(Get-Command -Name Connect-EXOPSSession -ErrorAction Ignore)) {
        Write-Verbose -Message 'Importing Microsoft.Exchange.Management.ExoPowershellModule ...'

        $ClickOnceAppsPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Apps\2.0'
        $ExoPowerShellModule = Get-ChildItem -Path $ClickOnceAppsPath -Recurse -Include 'Microsoft.Exchange.Management.ExoPowershellModule.manifest' | Sort-Object -Property LastWriteTime | Select-Object -Last 1
        $ExoPowerShellModulePs1 = Join-Path -Path $ExoPowerShellModule.Directory -ChildPath 'CreateExoPSSession.ps1'

        if ($ExoPowerShellModule) {
            # Sourcing the script rudely changes the current working directory
            $CurrentPath = Get-Location
            . $ExoPowerShellModulePs1
            Set-Location -Path $CurrentPath

            # Change the scope of imported functions to be global (better approach?)
            $Functions = @('Connect-EXOPSSession', 'Connect-IPPSSession', 'Test-Uri')
            foreach ($Function in $Functions) {
                $null = New-Item -Path Function: -Name global:$Function -Value (Get-Content -Path Function:\$Function)
            }
        } else {
            throw 'Required module not available: Microsoft.Exchange.Management.ExoPowershellModule'
        }
    }
}
