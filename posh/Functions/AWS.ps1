if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

try {
    if (!$DotFilesFastLoad) {
        Test-ModuleAvailable -Name AWS.Tools.Installer, AWSPowerShell.NetCore, AWSPowerShell -Require Any
    }
} catch {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping import of AWS functions.')
    $Error.RemoveAt(0)
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing AWS functions ...')

# Load our custom formatting data
$null = $FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'AWS.format.ps1xml'))

#region IAM

# Set AWS credentials environment variables from an AWSCredentials object
Function Set-AWSCredentialEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUsePSCredentialType', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object]$Credential
    )

    Process {
        try {
            $CorrectType = $Credential -is [Amazon.SecurityToken.Model.Credentials]
        } catch {
            throw 'Unable to locate Amazon.SecurityToken.Model.Credentials type.'
        }

        if (!$CorrectType) {
            throw 'Credential must be an Amazon.SecurityToken.Model.Credentials type.'
        }

        $env:AWS_ACCESS_KEY_ID = $Credential.AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $Credential.SecretAccessKey
        $env:AWS_SESSION_TOKEN = $Credential.SessionToken
    }
}

#endregion

#region Route 53

# Set the Name tag for a Route 53 hosted zone to the zone name
Function Set-R53HostedZoneNameTag {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]]$HostedZone
    )

    Begin {
        $Module = Test-ModuleAvailable -Name AWS.Tools.Route53, AWSPowerShell.NetCore, AWSPowerShell -Require Any -PassThru
        $Module | Import-Module -ErrorAction Stop -Verbose:$false

        $Tag = [Amazon.Route53.Model.Tag]::new()
        $Tag.Key = 'Name'
    }

    Process {
        foreach ($Zone in $HostedZone) {
            if ($Zone -isnot [Amazon.Route53.Model.HostedZone]) {
                Write-Error -Message 'Skipping zone which is not an Amazon.Route53.Model.HostedZone type.'
                continue
            }

            $ResourceId = $Zone.Id.Replace('/hostedzone/', [String]::Empty)
            $Tag.Value = $Zone.Name.TrimEnd('.')

            if ($PSCmdlet.ShouldProcess($Tag.Value, 'Set Name tag')) {
                Edit-R53TagsForResource -ResourceId $ResourceId -ResourceType hostedzone -AddTag $Tag
            }
        }
    }
}

# Set records on a Route 53 hosted zone for a parked domain
Function Set-R53HostedZoneParkedRecords {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Domain,

        [Parameter(Mandatory)]
        [ValidateSet('MX', 'SPF', 'DKIM', 'DMARC', 'CAA', 'Redirect')]
        [String[]]$Records,

        # E.g. mailto:dmarc-rua@domain.com
        [ValidateNotNullOrEmpty()]
        [String[]]$DmarcRua,
        # E.g. mailto:dmarc-ruf@domain.com
        [ValidateNotNullOrEmpty()]
        [String[]]$DmarcRuf,

        # E.g. amazon.com
        [ValidateNotNullOrEmpty()]
        [String[]]$CaaIssue,
        # E.g. digicert.com
        [ValidateNotNullOrEmpty()]
        [String[]]$CaaIssueWild,
        # E.g. mailto:netops@domain.com
        [ValidateNotNullOrEmpty()]
        [String[]]$CaaIoDef,

        # E.g. 1234567890ABCD.cloudfront.net.
        [ValidateNotNullOrEmpty()]
        [String]$RedirectCloudFrontDomainName,
        [ValidateSet('A', 'AAAA')]
        [String[]]$RedirectCloudFrontRecordTypes = 'A'
    )

    $Module = Test-ModuleAvailable -Name AWS.Tools.Route53, AWSPowerShell.NetCore, AWSPowerShell -Require Any -PassThru
    $Module | Import-Module -ErrorAction Stop -Verbose:$false

    try {
        $Zones = Get-R53HostedZoneList -ErrorAction Stop
    } catch {
        throw $_
    }

    $CloudFrontHostedZoneId = 'Z2FDTNDATAQYW2'
    $Changes = [Collections.ArrayList]::new()

    # Construct the DMARC record
    if ($Records -contains 'DMARC') {
        $Dmarc = 'v=DMARC1; p=reject'

        if ($DmarcRua) {
            $Dmarc = '{0}; rua={1}' -f $Dmarc, ($DmarcRua -join ',')
        }

        if ($DmarcRuf) {
            $Dmarc = '{0}; ruf={1}' -f $Dmarc, ($DmarcRuf -join ',')
        }

        $Dmarc = '{0}; fo=1' -f $Dmarc
    } elseif ($DmarcRua -or $DmarcRuf) {
        $IgnoredParams = @()

        if ($DmarcRua) {
            $IgnoredParams += 'DmarcRua'
        }

        if ($DmarcRuf) {
            $IgnoredParams += 'DmarcRuf'
        }

        if ($IgnoredParams.Count -ge 1) {
            Write-Warning -Message ('Parameter(s) will be ignored as not setting DMARC record: {0}' -f ($IgnoredParams -join ', '))
        }
    }

    # Construct each CAA record
    if ($Records -contains 'CAA') {
        $Caa = [Collections.ArrayList]::new()

        if ($CaaIssue) {
            foreach ($CaaIssuer in $CaaIssue) {
                $null = $Caa.Add('0 issue "{0}"' -f $CaaIssuer)
            }
        } else {
            $null = $Caa.Add('0 issue ";"')
        }

        if ($CaaIssueWild) {
            foreach ($CaaWildIssuer in $CaaIssueWild) {
                $null = $Caa.Add('0 issuewild "{0}"' -f $CaaWildIssuer)
            }
        }

        if ($CaaIoDef) {
            foreach ($CaaReportUrl in $CaaIoDef) {
                $null = $Caa.Add('0 iodef "{0}"' -f $CaaReportUrl)
            }
        }
    } elseif ($CaaIssue -or $CaaIssueWild -or $CaaIoDef) {
        $IgnoredParams = @()

        if ($CaaIssue) {
            $IgnoredParams += 'CaaIssue'
        }

        if ($CaaIssueWild) {
            $IgnoredParams += 'CaaIssueWild'
        }

        if ($CaaIoDef) {
            $IgnoredParams += 'CaaIoDef'
        }

        if ($IgnoredParams.Count -ge 1) {
            Write-Warning -Message ('Parameter(s) will be ignored as not setting CAA record: {0}' -f ($IgnoredParams -join ', '))
        }
    }

    # Check for CloudFront redirect parameters
    if ($Records -notcontains 'Redirect' -and ($RedirectCloudFrontDomainName -or $PSBoundParameters.ContainsKey('RedirectCloudFrontRecordTypes'))) {
        $IgnoredParams = @()

        if ($RedirectCloudFrontDomainName) {
            $IgnoredParams += 'RedirectCloudFrontDomainName'
        }

        if ($PSBoundParameters.ContainsKey('RedirectCloudFrontRecordTypes')) {
            $IgnoredParams += 'RedirectCloudFrontRecordTypes'
        }

        if ($IgnoredParams.Count -ge 1) {
            Write-Warning -Message ('Parameter(s) will be ignored as not setting redirect record(s): {0}' -f ($IgnoredParams -join ', '))
        }
    }

    # Process record changes for each zone
    foreach ($ZoneName in $Domain) {
        $ZoneName = $ZoneName.TrimEnd('.').ToLower()
        $ZoneFqdn = '{0}.' -f $ZoneName

        $Zone = $Zones | Where-Object Name -EQ $ZoneFqdn
        if (!$Zone) {
            Write-Warning -Message ('Unable to set records for non-existent zone: {0}' -f $ZoneName)
            continue
        }

        $ZoneRecords = [Collections.ArrayList]::new()

        if ($Records -contains 'MX') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = $ZoneName
            $Record.ResourceRecordSet.Type = 'MX'
            $Record.ResourceRecordSet.TTL = 3600
            $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = '0 .' })
            $null = $ZoneRecords.Add($Record)
        }

        if ($Records -contains 'SPF') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = $ZoneName
            $Record.ResourceRecordSet.Type = 'TXT'
            $Record.ResourceRecordSet.TTL = 3600
            $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = '"v=spf1 -all"' })
            $null = $ZoneRecords.Add($Record)
        }

        if ($Records -contains 'DKIM') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = ('*._domainkey.{0}' -f $ZoneName)
            $Record.ResourceRecordSet.Type = 'TXT'
            $Record.ResourceRecordSet.TTL = 3600
            $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = '"v=DKIM1; p="' })
            $null = $ZoneRecords.Add($Record)
        }

        if ($Records -contains 'DMARC') {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = ('_dmarc.{0}' -f $ZoneName)
            $Record.ResourceRecordSet.Type = 'TXT'
            $Record.ResourceRecordSet.TTL = 3600
            $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = ('"{0}"' -f $Dmarc) })
            $null = $ZoneRecords.Add($Record)
        }

        if ($Caa) {
            $Record = [Amazon.Route53.Model.Change]::new()
            $Record.Action = 'UPSERT'
            $Record.ResourceRecordSet = [Amazon.Route53.Model.ResourceRecordSet]::new()
            $Record.ResourceRecordSet.Name = $ZoneName
            $Record.ResourceRecordSet.Type = 'CAA'
            $Record.ResourceRecordSet.TTL = 900

            foreach ($Entry in $Caa) {
                $Record.ResourceRecordSet.ResourceRecords.Add(@{ Value = $Entry })
            }

            $null = $ZoneRecords.Add($Record)
        }

        if ($RedirectCloudFrontDomainName) {
            foreach ($RecordName in @($ZoneName, ('*.{0}' -f $ZoneName))) {
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
                    $null = $ZoneRecords.Add($Record)
                }
            }
        }

        $ZoneId = $Zone.Id.TrimStart('/hostedzone/')
        if ($PSCmdlet.ShouldProcess($ZoneName, 'Set records')) {
            $Change = Edit-R53ResourceRecordSet -HostedZoneId $ZoneId -ChangeBatch_Change $ZoneRecords -ChangeBatch_Comment $ZoneName
            $null = $Changes.Add($Change)
        }
    }

    return $Changes
}

# Set a tag on a Route 53 hosted zone
Function Set-R53HostedZoneTag {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]]$HostedZone,

        [Parameter(Mandatory)]
        [String]$Key,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$Value
    )

    Begin {
        $Module = Test-ModuleAvailable -Name AWS.Tools.Route53, AWSPowerShell.NetCore, AWSPowerShell -Require Any -PassThru
        $Module | Import-Module -ErrorAction Stop -Verbose:$false

        $Tag = [Amazon.Route53.Model.Tag]::new()
        $Tag.Key = $Key
        $Tag.Value = $Value
    }

    Process {
        foreach ($Zone in $HostedZone) {
            if ($Zone -isnot [Amazon.Route53.Model.HostedZone]) {
                Write-Error -Message 'Skipping zone which is not an Amazon.Route53.Model.HostedZone type.'
                continue
            }

            $ResourceId = $Zone.Id.Replace('/hostedzone/', [String]::Empty)

            if ($PSCmdlet.ShouldProcess($Zone.Name.TrimEnd('.'), 'Set {0} tag' -f $Tag.Key)) {
                Edit-R53TagsForResource -ResourceId $ResourceId -ResourceType hostedzone -AddTag $Tag
            }
        }
    }
}

#endregion

#region S3

# Retrieve the size of each S3 bucket
Function Get-S3BucketSize {
    [CmdletBinding()]
    Param()

    try {
        $Module = Test-ModuleAvailable -Name 'AWS.Tools.CloudWatch', 'AWS.Tools.EC2', 'AWS.Tools.S3' -PassThru
    } catch {
        $Module = Test-ModuleAvailable -Name AWSPowerShell.NetCore, AWSPowerShell -Require Any -PassThru
    }
    $Module | Import-Module -ErrorAction Stop -Verbose:$false

    try {
        Write-Verbose -Message 'Retrieving enabled regions ...'
        $Regions = Get-EC2Region -ErrorAction Stop -Verbose:$false

        Write-Verbose -Message 'Retrieving S3 buckets ...'
        $Buckets = Get-S3Bucket -ErrorAction Stop -Verbose:$false
    } catch {
        throw $_
    }

    foreach ($Bucket in $Buckets) {
        $Bucket.PSObject.TypeNames.Insert(0, 'Amazon.S3.Model.S3Bucket.Size')
    }

    Write-Verbose -Message 'Retrieving BucketSizeBytes metrics for enabled regions ...'
    $Metrics = @{}
    foreach ($Region in $Regions.RegionName) {
        try {
            $Result = Get-CWMetricList -Region $Region -MetricName BucketSizeBytes -ErrorAction Stop -Verbose:$false
        } catch {
            Write-Warning -Message ('Failed to retrieve BucketSizeBytes metrics for region: {0}' -f $Region)
            continue
        }

        if ($Result) {
            $Metrics[$Region] = $Result
        }
    }

    $CwMetricStatisticParams = @{
        Namespace   = 'AWS/S3'
        MetricName  = 'BucketSizeBytes'
        Statistic   = 'Average'
        Period      = 86400
        ErrorAction = 'Stop'
        Verbose     = $false
    }
    $CwMetricStatisticParams['UtcEndTime'] = (Get-Date).ToUniversalTime()
    $CwMetricStatisticParams['UtcStartTime'] = $CwMetricStatisticParams['UtcEndTime'].AddDays(-2)

    Write-Verbose -Message 'Retrieving BucketSizeBytes metric for each bucket ...'
    foreach ($Region in $Metrics.Keys) {
        foreach ($Metric in $Metrics[$Region]) {
            $BucketName = ($Metric.Dimensions | Where-Object Name -EQ 'BucketName').Value

            try {
                $Result = Get-CWMetricStatistic @CwMetricStatisticParams -Region $Region -Dimension $Metric.Dimensions
            } catch {
                Write-Warning -Message ('Failed to retrieve BucketSizeBytes metric for bucket: {0}' -f $BucketName)
                continue
            }

            $BucketSizeBytes = $Result.Datapoints[0].Average
            $BucketSize = $BucketSizeBytes | Format-SizeDigital

            $Bucket = $Buckets | Where-Object BucketName -EQ $BucketName
            $Bucket | Add-Member -MemberType NoteProperty -Name BucketSizeBytes -Value $BucketSizeBytes
            $Bucket | Add-Member -MemberType NoteProperty -Name BucketSize -Value $BucketSize
        }
    }

    $BucketSizeBytes = 0
    $BucketSize = $BucketSizeBytes | Format-SizeDigital
    foreach ($Bucket in $Buckets) {
        if (!$Bucket.PSObject.Properties['BucketSize']) {
            $Bucket | Add-Member -MemberType NoteProperty -Name BucketSizeBytes -Value $BucketSizeBytes
            $Bucket | Add-Member -MemberType NoteProperty -Name BucketSize -Value $BucketSize
        }
    }

    return $Buckets
}

#endregion
