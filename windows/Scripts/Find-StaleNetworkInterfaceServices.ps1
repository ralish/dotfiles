<#
    Find stale network interface "services" in the registry.

    These registry keys reside under HKLM\System\CurrentControlSet\Services,
    alongside traditional Windows services, with the key name being a GUID.
    They aren't true services as they're missing values required by the SCM.

    I'm not actually clear what creates/manages them, but they appear to be
    paired to actual network interfaces (physical or virtual), but aren't
    cleaned-up when the associated network interface no longer exists.

    The best logic I've found so far for determining which are stale is:
    - The GUID service key has a "tcpip" sub-key
    - The "tcpip" sub-key has an "IPAddress" value
    - The "IPAddress" value data is an IP address no network interface has
#>

[CmdletBinding()]
Param(
    [Switch]$SkipGuidRefSearch
)

$Results = [Collections.Generic.List[PSCustomObject]]::new()

$NetIPAddresses = Get-NetIPAddress

$ServicesPath = 'HKLM:\System\CurrentControlSet\Services'
$ServicesKey = Get-Item -Path $ServicesPath

$GuidRegex = '^\{[a-z0-9]{8}(-[a-z0-9]{4}){3}-[a-z0-9]{12}\}$'
$GuidServices = $ServicesKey.GetSubKeyNames() | Where-Object { $_ -match $GuidRegex }

foreach ($GuidService in $GuidServices) {
    $ServiceGuid = [Guid]($GuidService -replace '[\{\}]')
    $ServicePath = Join-Path -Path $ServicesPath -ChildPath $GuidService

    $ServiceInfo = [PSCustomObject]@{
        Guid    = $ServiceGuid
        Path    = $ServicePath
        Status  = 'Unknown'
        Matches = $null
    }
    $Results.Add($ServiceInfo)

    $TcpipParamsPath = Join-Path $ServicePath -ChildPath 'Parameters\Tcpip'
    try {
        $TcpipParamsKey = Get-Item -Path $TcpipParamsPath -ErrorAction Stop
    } catch {
        $ServiceInfo.Status = 'Tcpip registry key missing'
        continue
    }

    $IPAddresses = $TcpipParamsKey.GetValue('IPAddress')
    if ($null -eq $IPAddresses) {
        $ServiceInfo.Status = 'IPAddress registry value missing'
        continue
    }

    if ($IPAddresses[0].Count -eq 0) {
        $ServiceInfo.Status = 'IPAddress registry value empty'
        continue
    }

    $IPAddressNotPresent = $false
    foreach ($IPAddress in $IPAddresses[0]) {
        if ($IPAddress -notin $NetIPAddresses.IPAddress) {
            $IPAddressNotPresent = $IPAddress
            break
        }
    }

    if ($IPAddressNotPresent) {
        $ServiceInfo.Status = 'IP address not present: {0}' -f $IPAddressNotPresent
        continue
    }

    $ServiceInfo.Status = 'OK'
}

if (!$SkipGuidRefSearch) {
    return $Results
}

foreach ($GuidService in $Results) {
    if ($GuidService.Status -eq 'OK') {
        continue
    }

    $SearchParams = @{
        Hive        = 'HKLM'
        Path        = 'System\CurrentControlSet'
        SimpleMatch = '*{0}*' -f $GuidService.Guid
        Verbose     = $false
    }

    Write-Verbose -Message ('Searching registry for references to GUID: {0}' -f $GuidService.Guid)
    $GuidService.Matches = Search-Registry @SearchParams
}

return $Results
