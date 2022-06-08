<#
    Install .NET Framework 3.5 on Windows releases for which it's an optional
    operating system component.
#>

[CmdletBinding()]
[OutputType([Void], [String[]])]
Param(
    [ValidateNotNullOrEmpty()]
    [String]$SxsPath
)

$WmiCommand = 'Get-CimInstance'
if (Get-Command -Name 'Get-WmiObject' -ErrorAction SilentlyContinue) {
    $WmiCommand = 'Get-WmiObject'
}

$Win32OpSys = & $WmiCommand -Class Win32_OperatingSystem -Verbose:$false
$BuildNumber = [int]$Win32OpSys.BuildNumber

$DismParams = [Collections.Generic.List[String]]@(
    '/Online',
    '/Enable-Feature',
    '/FeatureName:NetFx3'
)

if ($SxsPath) {
    $DismParams.Add(('/Source:{0}' -f $SxsPath))
}

# The /All parameter is only available from Windows 8 / Server 2012
if ($BuildNumber -ge 9200) {
    $DismParams.Add('/All')
}

Start-Process -FilePath 'dism.exe' -ArgumentList $DismParams -NoNewWindow -Wait
