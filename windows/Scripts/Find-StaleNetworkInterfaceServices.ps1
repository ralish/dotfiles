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

[CmdletBinding()]
[OutputType([Void], [PSCustomObject[]])]
Param(
    [Switch]$GuidRefSearch
)

$ServicesPath = 'HKLM:\System\CurrentControlSet\Services'
$GuidRegex = '^\{[a-z0-9]{8}(-[a-z0-9]{4}){3}-[a-z0-9]{12}\}$'

$Results = [Collections.Generic.List[PSCustomObject]]::new()
$NetIPAddresses = Get-NetIPAddress
$ServicesKey = Get-Item -LiteralPath $ServicesPath
$GuidServices = $ServicesKey.GetSubKeyNames() | Where-Object { $_ -match $GuidRegex }

if ($GuidServices.Count -eq 0) {
    Write-Verbose -Message 'No network interface services keys found.'
    return
}

Write-Verbose -Message "Enumerating $($GuidServices.Count) network interface services keys ..."
foreach ($GuidService in $GuidServices) {
    $ServiceGuid = [Guid]($GuidService -replace '[\{\}]')
    $ServicePath = Join-Path -Path $ServicesPath -ChildPath $GuidService

    $ServiceInfo = [PSCustomObject]@{
        Guid    = $ServiceGuid
        Path    = $ServicePath
        Status  = 'Unknown'
        Details = ''
        Matches = $null
    }
    $Results.Add($ServiceInfo)

    try {
        $TcpipParamsPath = Join-Path $ServicePath -ChildPath 'Parameters\Tcpip'
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
            Write-Warning -Message "[$ServiceGuid] Unexpected value for EnableDHCP: $EnableDHCP"
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
