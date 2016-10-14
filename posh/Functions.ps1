Function Connect-AllOffice365Services {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$true)]
            [String]$SharePointDomainName,
            [String]$SccCmdletsPrefix='Scc'
    )

    Connect-Office365 -Credential $Credential
    Connect-SharePointOnline -Credential $Credential -DomainName $SharePointDomainName
    Connect-SkypeForBusinessOnline -Credential $Credential
    Connect-ExchangeOnline -Credential $Credential
    Connect-SecurityAndComplianceCenter -Credential $Credential -CmdletsPrefix $SccCmdletsPrefix
}

Function Connect-ExchangeOnline {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.Management.Automation.PSCredential]$Credential
    )

    Write-Verbose 'Connecting to Exchange Online ...'
    $ExchangeOnline = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $Credential -Authentication 'Basic' -AllowRedirection
    Import-PSSession $ExchangeOnline -DisableNameChecking
}

Function Connect-Office365 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.Management.Automation.PSCredential]$Credential
    )

    if (!(Get-Module -Name MSOnline -ListAvailable)) {
        throw 'Required module not available: MSOnline'
    }

    Write-Verbose 'Connecting to Office 365 ...'
    Import-Module MSOnline
    Connect-MsolService -Credential $Credential
}

Function Connect-SecurityAndComplianceCenter {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.Management.Automation.PSCredential]$Credential,
            [String]$CmdletsPrefix='Scc'
    )

    Write-Verbose 'Connecting to Security and Compliance Center ...'
    $SCC = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://ps.compliance.protection.outlook.com/powershell-liveid/' -Credential $Credential -Authentication 'Basic' -AllowRedirection
    Import-PSSession $SCC -Prefix $CmdletsPrefix
}

Function Connect-SharePointOnline {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$true)]
            [String]$DomainName
    )

    if (!(Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
        throw 'Required module not available: Microsoft.Online.SharePoint.PowerShell'
    }

    Write-Verbose 'Connecting to SharePoint Online ...'
    Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
    $SPOUrl = "https://$DomainName-admin.sharepoint.com"
    Connect-SPOService -Url $SPOUrl -Credential $Credential
}

Function Connect-SkypeForBusinessOnline {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.Management.Automation.PSCredential]$Credential
    )

    if (!(Get-Module -Name SkypeOnlineConnector -ListAvailable)) {
        throw 'Required module not available: SkypeOnlineConnector'
    }

    Write-Verbose 'Connecting to Skype for Business Online ...'
    Import-Module SkypeOnlineConnector
    $SkypeForBusinessOnline = New-CsOnlineSession -Credential $Credential
    Import-PSSession $SkypeForBusinessOnline
}

# Convert a string to the Base64 form suitable for usage with PowerShell's "-EncodedCommand" parameter
Function ConvertTo-PoShBase64 {
    Param(
        [Parameter(Position=1,Mandatory=$true)]
            [String]$String
    )

    [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("$String"))
}

# Convert a string from the Base64 form suitable for usage with PowerShell's "-EncodedCommand" parameter
Function ConvertFrom-PoShBase64 {
    Param(
        [Parameter(Position=1,Mandatory=$true)]
            [String]$String
    )

    [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String("$String"))
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
        Get-EventLog -LogName $EventLog -Newest ($idx2 - $idx1) | Sort Index
        $idx1 = $idx2
    } while ($true)
}

# The MKLINK command is actually part of the Command Processor (cmd.exe)
# So we have a quick and dirty function below to invoke it via PowerShell
Function mklink {
    cmd /c mklink $args
}
