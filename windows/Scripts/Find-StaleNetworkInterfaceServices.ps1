<#
    Find stale network interface "services" in the registry.

    These registry keys reside under `HKLM\System\CurrentControlSet\Services`,
    alongside traditional Windows services, with the key name being a GUID.
    They aren't true services as they're missing values required by the SCM.

    I'm not actually clear what creates/manages them, but they appear to be
    paired to actual network interfaces (physical or virtual), but aren't
    cleaned-up when the associated network interface no longer exists.

    The best logic I've found so far for determining which are stale is:
    - The GUID service key has a `tcpip` sub-key
    - The `tcpip` sub-key has an `IPAddress` value
    - The `IPAddress` value data is an IP address no network interface has
#>

#Requires -Version 5.0

[CmdletBinding()]
[OutputType([Void], [PSCustomObject[]])]
Param(
    [Switch]$GuidRefSearch
)

if ($GuidRefSearch) {
    if (!(Test-Path -LiteralPath 'Function:\Search-Registry')) {
        $ErrMsg = 'Missing Search-Registry function required for -GuidRefSearch parameter.'
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new([Exception]::new($ErrMsg), 'FunctionNotFound', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }
}

$ServicesPath = 'HKLM:\System\CurrentControlSet\Services'
$GuidRegex = '^\{[a-z0-9]{8}(-[a-z0-9]{4}){3}-[a-z0-9]{12}\}$'

Write-Verbose -Message 'Retrieving network interface services registry keys ...'
$ServicesKey = Get-Item -LiteralPath $ServicesPath
$GuidServices = $ServicesKey.GetSubKeyNames() | Where-Object { $PSItem -match $GuidRegex }
if ($GuidServices.Count -eq 0) {
    Write-Warning -Message 'No network interface services registry keys found.'
    return
}

Write-Verbose -Message 'Retrieving network adapter IP addresses ...'
$NetIPAddresses = Get-NetIPAddress

Write-Verbose -Message "Processing $($GuidServices.Count) network interface services registry keys ..."
$Results = [Collections.Generic.List[PSCustomObject]]::new()
foreach ($GuidService in $GuidServices) {
    $ServiceGuid = [Guid]($GuidService -replace '[\{\}]')
    $ServicePath = Join-Path -Path $ServicesPath -ChildPath $GuidService
    Write-Debug -Message "Processing network interface service registry key: ${ServiceGuid}"

    $ServiceInfo = [PSCustomObject]@{
        Guid    = $ServiceGuid
        Path    = $ServicePath
        Status  = 'Unknown'
        Details = ''
        Matches = $null
    }
    $Results.Add($ServiceInfo)

    try {
        $TcpipParamsPath = Join-Path -Path $ServicePath -ChildPath 'Parameters\Tcpip'
        $TcpipParamsKey = Get-Item -LiteralPath $TcpipParamsPath -ErrorAction 'Stop'
    } catch {
        $ServiceInfo.Details = 'Tcpip registry key missing'
        continue
    }

    $EnableDHCP = $TcpipParamsKey.GetValue('EnableDHCP')
    if ($null -ne $EnableDHCP) {
        if ($EnableDHCP -eq 1) {
            $ServiceInfo.Status = 'OK'
            $ServiceInfo.Details = 'Interface is using DHCP'
            continue
        }

        if ($EnableDHCP -ne 0) {
            Write-Warning -Message "[${ServiceGuid}] Unexpected value for EnableDHCP: ${EnableDHCP}"
        }
    }

    $IPAddresses = $TcpipParamsKey.GetValue('IPAddress')
    if ($null -eq $IPAddresses) {
        $ServiceInfo.Details = 'IPAddress registry value missing'
        continue
    }

    if ($IPAddresses.Count -eq 0) {
        $ServiceInfo.Details = 'IPAddress registry value empty'
        continue
    }

    $MissingIPAddresses = @()
    foreach ($IPAddress in $IPAddresses) {
        if ($IPAddress -notin $NetIPAddresses.IPAddress) {
            $MissingIPAddresses += $IPAddress
        }
    }

    if ($MissingIPAddresses.Count -ne 0) {
        $ServiceInfo.Status = 'Orphaned'
        $ServiceInfo.Details = "IP address(es) not present: $($MissingIPAddresses -join ',')"
        continue
    }

    $ServiceInfo.Status = 'OK'
    $ServiceInfo.Details = "All static IPs present ($($IPAddresses.Count) total)"
}

if ($GuidRefSearch) {
    foreach ($GuidService in $Results) {
        if ($GuidService.Status -eq 'OK') { continue }

        $SearchParams = @{
            Hive        = 'HKLM'
            Path        = 'System\CurrentControlSet'
            SimpleMatch = "*$($GuidService.Guid)*"
            Verbose     = $false
        }

        Write-Verbose -Message "Searching registry for references to GUID: $($GuidService.Guid)"
        $GuidService.Matches = Search-Registry @SearchParams
    }
}

return $Results
