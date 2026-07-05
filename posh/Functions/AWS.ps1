$DotFilesSection = @{
    Type          = 'Functions'
    Name          = 'AWS'
    Module        = 'AWS.Tools.Installer', 'AWSPowerShell.NetCore', 'AWSPowerShell'
    ModuleRequire = 'Any'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'AWS.format.ps1xml'))

#region IAM

# Set AWS credential environment variables
Function Global:Set-AWSCredentialEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUsePSCredentialType', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        # The AWS type may not be available at the time the function is sourced
        # due to lazy import of the appropriate AWS module.
        [Parameter(ParameterSetName = 'AWSCredentials', Mandatory, ValueFromPipeline)]
        [PSObject]$Credential, # Amazon.SecurityToken.Model.Credentials

        [Parameter(ParameterSetName = 'PlainText', Mandatory)]
        [String]$AccessKey,

        [Parameter(ParameterSetName = 'PlainText', Mandatory)]
        [String]$SecretKey,

        [Parameter(ParameterSetName = 'PlainText')]
        [ValidateNotNullOrEmpty()]
        [String]$SessionToken
    )

    Begin {
        if ($PSCmdlet.ParameterSetName -eq 'AWSCredentials') {
            $Module = Test-ModuleAvailable -Name 'AWS.Tools.SecurityToken', 'AWSPowerShell.NetCore', 'AWSPowerShell' -Require 'Any' -PassThru
            $Module | Import-Module -ErrorAction 'Stop' -Verbose:$false
        }
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'PlainText') {
            $Env:AWS_ACCESS_KEY_ID = $AccessKey
            $Env:AWS_SECRET_ACCESS_KEY = $SecretKey
            $Env:AWS_SESSION_TOKEN = $SessionToken
            return
        }

        if ($Credential.GetType().FullName -ne 'Amazon.SecurityToken.Model.Credentials') {
            $ExcMsg = "Unexpected type for Credential argument: $($Credential.GetType().FullName)"
            $ErrExc = [ArgumentException]::new($ExcMsg, 'Credential')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidType
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidType', $ErrCat, $Credential)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }

        $Env:AWS_ACCESS_KEY_ID = $Credential.AccessKeyId
        $Env:AWS_SECRET_ACCESS_KEY = $Credential.SecretAccessKey
        $Env:AWS_SESSION_TOKEN = $Credential.SessionToken
    }
}

#endregion

#region Route 53

# Set the `Name` tag for a Route 53 hosted zone to the zone name
Function Global:Set-R53HostedZoneNameTag {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        # The AWS type may not be available at the time the function is sourced
        # due to lazy import of the appropriate AWS module.
        [Parameter(Mandatory, ValueFromPipeline)]
        [Array]$HostedZone # `Amazon.Route53.Model.HostedZone[]`
    )

    Begin {
        $Module = Test-ModuleAvailable -Name 'AWS.Tools.Route53', 'AWSPowerShell.NetCore', 'AWSPowerShell' -Require 'Any' -PassThru
        $Module | Import-Module -ErrorAction 'Stop' -Verbose:$false

        $Tag = [Amazon.Route53.Model.Tag]::new()
        $Tag.Key = 'Name'
    }

    Process {
        foreach ($Zone in $HostedZone) {
            if ($Zone.GetType().FullName -ne 'Amazon.Route53.Model.HostedZone') {
                $ExcMsg = 'Skipping zone which is not of expected type: Amazon.Route53.Model.HostedZone'
                $ErrExc = [ArgumentException]::new($ExcMsg, 'HostedZone')
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidType
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidType', $ErrCat, $Zone)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            $Tag.Value = $Zone.Name.TrimEnd('.')
            if ($PSCmdlet.ShouldProcess($Tag.Value, 'Set Name tag')) {
                try {
                    $ResourceId = $Zone.Id -replace '^/hostedzone/'
                    Edit-R53TagsForResource -ResourceId $ResourceId -ResourceType 'hostedzone' -AddTag $Tag -ErrorAction 'Stop'
                } catch { $PSCmdlet.WriteError($PSItem) }
            }
        }
    }
}

# Set records on a Route 53 hosted zone suitable for a parked domain
Function Global:Set-R53HostedZoneParkedRecords {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('Amazon.Route53.Model.ChangeInfo[]')]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Domain,

        [Parameter(Mandatory)]
        [ValidateSet('MX', 'SPF', 'DKIM', 'DMARC', 'CAA', 'Redirect')]
        [String[]]$Records,

        # E.g. `mailto:dmarc-rua@domain.com`
        [ValidateNotNullOrEmpty()]
        [String[]]$DmarcRua,

        # E.g. `mailto:dmarc-ruf@domain.com`
        [ValidateNotNullOrEmpty()]
        [String[]]$DmarcRuf,

        # E.g. `amazon.com`
        [ValidateNotNullOrEmpty()]
        [String[]]$CaaIssue,

        # E.g. `digicert.com`
        [ValidateNotNullOrEmpty()]
        [String[]]$CaaIssueWild,

        # E.g. `mailto:netops@domain.com`
        [ValidateNotNullOrEmpty()]
        [String[]]$CaaIoDef,

        # E.g. `1234567890ABCD.cloudfront.net.`
        [ValidateNotNullOrEmpty()]
        [String]$RedirectCloudFrontDomainName,

        [ValidateSet('A', 'AAAA')]
        [String[]]$RedirectCloudFrontRecordTypes = 'A'
    )

    $Module = Test-ModuleAvailable -Name 'AWS.Tools.Route53', 'AWSPowerShell.NetCore', 'AWSPowerShell' -Require 'Any' -PassThru
    $Module | Import-Module -ErrorAction 'Stop' -Verbose:$false

    if ($Records -contains 'Redirect' -and !$RedirectCloudFrontDomainName) {
        $ExcMsg = 'Must specify RedirectCloudFrontDomainName parameter when setting redirect records.'
        $ErrExc = [ArgumentException]::new($ExcMsg, 'RedirectCloudFrontDomainName')
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSMissingParameter', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    try {
        $Zones = Get-R53HostedZoneList -ErrorAction 'Stop'
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    # Always the hosted zone ID for creating alias records that route traffic
    # to a CloudFront distribution.
    $CloudFrontHostedZoneId = 'Z2FDTNDATAQYW2'

    $Changes = [Collections.Generic.List[Amazon.Route53.Model.ChangeInfo]]::new()

    # Construct the DMARC record
    if ($Records -contains 'DMARC') {
        $Dmarc = 'v=DMARC1; p=reject'

        if ($DmarcRua) {
            $Dmarc = "${Dmarc}; rua=$($DmarcRua -join ',')"
        }

        if ($DmarcRuf) {
            $Dmarc = "${Dmarc}; ruf=$($DmarcRuf -join ',')"
        }

        $Dmarc = "${Dmarc}; fo=1"
    } elseif ($DmarcRua -or $DmarcRuf) {
        $IgnoredParams = @()

        if ($DmarcRua) { $IgnoredParams += 'DmarcRua' }
        if ($DmarcRuf) { $IgnoredParams += 'DmarcRuf' }

        Write-Warning -Message "Parameter(s) will be ignored as not setting DMARC record: $($IgnoredParams -join ', ')"
    }

    # Construct each CAA record
    if ($Records -contains 'CAA') {
        $Caa = [Collections.Generic.List[String]]::new()

        if ($CaaIssue) {
            foreach ($CaaIssuer in $CaaIssue) {
                $Caa.Add('0 issue "{0}"' -f $CaaIssuer)
            }
        } else {
            $Caa.Add('0 issue ";"')
        }

        if ($CaaIssueWild) {
            foreach ($CaaWildIssuer in $CaaIssueWild) {
                $Caa.Add('0 issuewild "{0}"' -f $CaaWildIssuer)
            }
        }

        if ($CaaIoDef) {
            foreach ($CaaReportUrl in $CaaIoDef) {
                $Caa.Add('0 iodef "{0}"' -f $CaaReportUrl)
            }
        }
    } elseif ($CaaIssue -or $CaaIssueWild -or $CaaIoDef) {
        $IgnoredParams = @()

        if ($CaaIssue) { $IgnoredParams += 'CaaIssue' }
        if ($CaaIssueWild) { $IgnoredParams += 'CaaIssueWild' }
        if ($CaaIoDef) { $IgnoredParams += 'CaaIoDef' }

        Write-Warning -Message "Parameter(s) will be ignored as not setting CAA record: $($IgnoredParams -join ', ')"
    }

    # Check for CloudFront redirect parameters
    if ($Records -notcontains 'Redirect' -and ($RedirectCloudFrontDomainName -or $PSBoundParameters.ContainsKey('RedirectCloudFrontRecordTypes'))) {
        $IgnoredParams = @()

        if ($RedirectCloudFrontDomainName) { $IgnoredParams += 'RedirectCloudFrontDomainName' }

        if ($PSBoundParameters.ContainsKey('RedirectCloudFrontRecordTypes')) {
            $IgnoredParams += 'RedirectCloudFrontRecordTypes'
        }

        Write-Warning -Message "Parameter(s) will be ignored as not setting redirect record(s): $($IgnoredParams -join ', ')"
    }

    # Process record changes for each zone
    foreach ($ZoneName in $Domain) {
        $ZoneName = $ZoneName.TrimEnd('.').ToLower()
        $ZoneFqdn = "${ZoneName}."
        $Zone = $Zones | Where-Object Name -EQ $ZoneFqdn

        if (!$Zone) {
            $ExcMsg = "Unable to set records for non-existent zone: ${ZoneName}"
            $ErrExc = [InvalidOperationException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'AwsRoute53ZoneNotFound', $ErrCat, $ZoneName)
            $PSCmdlet.WriteError($ErrRec)
            continue
        }

        if ($Zone -is [Array]) {
            $ExcMsg = "Skipping FQDN which returned multiple zones: ${ZoneName}"
            $ErrExc = [InvalidOperationException]::new($ExcMsg)
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'AwsRoute53MultipleZones', $ErrCat, $ZoneName)
            $PSCmdlet.WriteError($ErrRec)
            continue
        }

        $ZoneRecords = [Collections.Generic.List[Amazon.Route53.Model.Change]]::new()

        if ($Records -contains 'MX') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = $ZoneName
            $Record.ResourceRecordSet.Type = 'MX'
            $Record.ResourceRecordSet.TTL = 3600
            $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = '0 .' })
            $ZoneRecords.Add($Record)
        }

        if ($Records -contains 'SPF') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = $ZoneName
            $Record.ResourceRecordSet.Type = 'TXT'
            $Record.ResourceRecordSet.TTL = 3600
            $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = '"v=spf1 -all"' })
            $ZoneRecords.Add($Record)
        }

        if ($Records -contains 'DKIM') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = "*._domainkey.${ZoneName}"
            $Record.ResourceRecordSet.Type = 'TXT'
            $Record.ResourceRecordSet.TTL = 3600
            $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = '"v=DKIM1; p="' })
            $ZoneRecords.Add($Record)
        }

        if ($Records -contains 'DMARC') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = "_dmarc.${ZoneName}"
            $Record.ResourceRecordSet.Type = 'TXT'
            $Record.ResourceRecordSet.TTL = 3600
            $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = ('"{0}"' -f $Dmarc) })
            $ZoneRecords.Add($Record)
        }

        if ($Records -contains 'CAA') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = $ZoneName
            $Record.ResourceRecordSet.Type = 'CAA'
            $Record.ResourceRecordSet.TTL = 900

            foreach ($Entry in $Caa) {
                $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = $Entry })
            }

            $ZoneRecords.Add($Record)
        }

        if ($Records -contains 'Redirect') {
            foreach ($RecordName in @($ZoneName, "*.${ZoneName}")) {
                foreach ($RecordType in $RedirectCloudFrontRecordTypes) {
                    $Record = [Amazon.Route53.Model.Change]::new()
                    $Record.Action = 'UPSERT'
                    $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
                    $Record.ResourceRecordSet.Name = $RecordName
                    $Record.ResourceRecordSet.Type = $RecordType
                    $Record.ResourceRecordSet.AliasTarget = [Amazon.Route53.Model.AliasTarget]::new()
                    $Record.ResourceRecordSet.AliasTarget.HostedZoneId = $CloudFrontHostedZoneId
                    $Record.ResourceRecordSet.AliasTarget.DNSName = $RedirectCloudFrontDomainName
                    $Record.ResourceRecordSet.AliasTarget.EvaluateTargetHealth = $false
                    $ZoneRecords.Add($Record)
                }
            }
        }

        if ($PSCmdlet.ShouldProcess($ZoneName, 'Set records')) {
            try {
                $ZoneId = $Zone.Id -replace '^/hostedzone/'
                $Change = Edit-R53ResourceRecordSet -HostedZoneId $ZoneId -ChangeBatch_Change $ZoneRecords -ChangeBatch_Comment $ZoneName -ErrorAction 'Stop'
                $Changes.Add($Change)
            } catch { $PSCmdlet.WriteError($PSItem) }
        }
    }

    return $Changes.ToArray()
}

# Set a tag on a Route 53 hosted zone
Function Global:Set-R53HostedZoneTag {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        # The AWS type may not be available at the time the function is sourced
        # due to lazy import of the appropriate AWS module.
        [Parameter(Mandatory, ValueFromPipeline)]
        [Array]$HostedZone, # `Amazon.Route53.Model.HostedZone[]`

        [Parameter(Mandatory)]
        [String]$Key,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$Value
    )

    Begin {
        $Module = Test-ModuleAvailable -Name 'AWS.Tools.Route53', 'AWSPowerShell.NetCore', 'AWSPowerShell' -Require 'Any' -PassThru
        $Module | Import-Module -ErrorAction 'Stop' -Verbose:$false

        $Tag = [Amazon.Route53.Model.Tag]::new()
        $Tag.Key = $Key
        $Tag.Value = $Value
    }

    Process {
        foreach ($Zone in $HostedZone) {
            if ($Zone.GetType().FullName -ne 'Amazon.Route53.Model.HostedZone') {
                $ExcMsg = 'Skipping zone which is not of expected type: Amazon.Route53.Model.HostedZone'
                $ErrExc = [ArgumentException]::new($ExcMsg, 'HostedZone')
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidType
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidType', $ErrCat, $Zone)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            if ($PSCmdlet.ShouldProcess($Zone.Name.TrimEnd('.'), "Set $($Tag.Key) tag")) {
                try {
                    $ResourceId = $Zone.Id -replace '^/hostedzone/'
                    Edit-R53TagsForResource -ResourceId $ResourceId -ResourceType 'hostedzone' -AddTag $Tag -ErrorAction 'Stop'
                } catch { $PSCmdlet.WriteError($PSItem) }
            }
        }
    }
}

#endregion

#region S3

# Retrieve the size of every AWS S3 bucket
Function Global:Get-S3BucketSize {
    [CmdletBinding()]
    [OutputType('Void', 'Amazon.S3.Model.S3Bucket[]')]
    Param()

    $ModulesPerService = 'AWS.Tools.CloudWatch', 'AWS.Tools.EC2', 'AWS.Tools.S3'
    $ModulesMonolithic = 'AWSPowerShell.NetCore', 'AWSPowerShell'

    try {
        $Modules = Test-ModuleAvailable -Name $ModulesPerService -PassThru
    } catch {
        try {
            $Modules = Test-ModuleAvailable -Name $ModulesMonolithic -Require 'Any' -PassThru
        } catch {
            $ErrObj = "$($ModulesPerService -join ', ') | $($ModulesMonolithic -join ' | ')"
            $ExcMsg = "Valid set of modules not available: ${ErrObj}"
            $ErrExc = [Exception]::new($ExcMsg, $PSItem.Exception)
            $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleNotFound', $ErrCat, $ErrObj)
            $PSCmdlet.ThrowTerminatingError($ErrRec)
        }
    }

    $ModuleVersionMajor = @($Modules.Version.Major | Sort-Object -Unique)
    if ($ModuleVersionMajor.Count -ne 1) {
        $ExcMsg = "AWS modules span multiple major versions: $($ModuleVersionMajor -join ', ')"
        $ErrExc = [InvalidOperationException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSModuleMismatch', $ErrCat, $Modules)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $ModuleVersionMajor = $ModuleVersionMajor[0]
    $Modules | Import-Module -ErrorAction 'Stop' -Verbose:$false

    try {
        Write-Verbose -Message 'Retrieving enabled regions ...'
        $Regions = Get-EC2Region -ErrorAction 'Stop' -Verbose:$false
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    try {
        Write-Verbose -Message 'Retrieving S3 buckets ...'
        $Buckets = Get-S3Bucket -ErrorAction 'Stop' -Verbose:$false
    } catch { $PSCmdlet.ThrowTerminatingError($PSItem) }

    if (!$Buckets) {
        Write-Warning -Message 'Retrieved no S3 buckets.'
        return
    }

    foreach ($Bucket in $Buckets) {
        $Bucket.PSObject.TypeNames.Insert(0, 'Amazon.S3.Model.S3Bucket.Size')
        $Bucket | Add-Member -MemberType 'NoteProperty' -Name 'BucketSizeBytes' -Value 0
        $Bucket | Add-Member -MemberType 'ScriptProperty' -Name 'BucketSize' -Value { $this.BucketSizeBytes | Format-SizeDigital }
    }

    Write-Verbose -Message 'Retrieving BucketSizeBytes metrics for enabled regions ...'
    $MetricsPerRegion = @{}
    foreach ($Region in $Regions.RegionName) {
        try {
            $Metrics = Get-CWMetricList -Region $Region -MetricName 'BucketSizeBytes' -ErrorAction 'Stop' -Verbose:$false
            $MetricsPerRegion[$Region] = $Metrics
        } catch {
            Write-Warning -Message "Failed to retrieve BucketSizeBytes metrics for region: ${Region}"
        }
    }

    $CwMetricStatisticParams = @{
        Namespace  = 'AWS/S3'
        MetricName = 'BucketSizeBytes'
        Statistic  = 'Average'
        Period     = 86400
        Verbose    = $false
    }

    $EndTime = (Get-Date).ToUniversalTime()
    $StartTime = $EndTime.AddDays(-2)
    if ($ModuleVersionMajor -ge 5) {
        $CwMetricStatisticParams['EndTime'] = $EndTime
        $CwMetricStatisticParams['StartTime'] = $StartTime
    } else {
        $CwMetricStatisticParams['UtcEndTime'] = $EndTime
        $CwMetricStatisticParams['UtcStartTime'] = $StartTime
    }

    Write-Verbose -Message 'Retrieving BucketSizeBytes metric for each S3 bucket ...'
    foreach ($Region in $MetricsPerRegion.Keys) {
        foreach ($Metric in $MetricsPerRegion[$Region]) {
            $BucketName = $StorageType = $null
            $UnknownDimension = $false

            foreach ($Dimension in $Metric.Dimensions) {
                switch ($Dimension.Name) {
                    'BucketName' { $BucketName = $Dimension.Value }
                    'StorageType' { $StorageType = $Dimension.Value }

                    default {
                        $UnknownDimension = $true

                        $ExcMsg = "Skipping BucketSizeBytes metric with unknown dimension: $($Dimension.Name)"
                        $ErrExc = [NotSupportedException]::new($ExcMsg)
                        $ErrCat = [Management.Automation.ErrorCategory]::NotImplemented
                        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'AwsCloudWatchUnknownMetricDimension', $ErrCat, $Metric)
                        $PSCmdlet.WriteError($ErrRec)
                    }
                }
            }

            if ($UnknownDimension) { continue }

            if (!$BucketName -or !$StorageType) {
                $ExcMsg = 'Skipping BucketSizeBytes metric missing BucketName and/or StorageType dimension.'
                $ErrExc = [InvalidOperationException]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'AwsCloudWatchMissingMetricDimension', $ErrCat, $Metric)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            $Bucket = $Buckets | Where-Object BucketName -EQ $BucketName
            if (!$Bucket) {
                $ExcMsg = "Skipping BucketSizeBytes metric for unknown bucket: ${BucketName}"
                $ErrExc = [InvalidOperationException]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'AwsCloudWatchUnknownBucketInMetric', $ErrCat, $Metric)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            try {
                $Statistic = Get-CWMetricStatistic @CwMetricStatisticParams -Region $Region -Dimension $Metric.Dimensions -ErrorAction 'Stop'
            } catch {
                Write-Warning -Message "Failed to retrieve BucketSizeBytes metric for ${StorageType} of S3 bucket: ${BucketName}"
                continue
            }

            if ($Statistic.Datapoints.Count -eq 0) {
                $ExcMsg = "Skipping BucketSizeBytes statistic with $($Statistic.Datapoints.Count) datapoints for S3 bucket: ${BucketName}"
                $ErrExc = [InvalidOperationException]::new($ExcMsg)
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'AwsCloudWatchInvalidDatapointsCount', $ErrCat, $Statistic)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            $Bucket.BucketSizeBytes += ($Statistic.Datapoints | Sort-Object -Property 'Timestamp' -Descending)[0].Average
        }
    }

    return $Buckets
}

#endregion

Complete-DotFilesSection
