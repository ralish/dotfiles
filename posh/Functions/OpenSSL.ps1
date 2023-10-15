Start-DotFilesSection -Type 'Functions' -Name 'OpenSSL'

# Convert a certificate in DER format to PEM format
Function Convert-OpenSSLDerToPem {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$DerFile,

        [Parameter(Mandatory)]
        [String]$PemFile
    )

    $Params = @(
        'x509',
        '-inform', 'der',
        '-in', $DerFile,
        '-out', $PemFile
    )

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Convert a certificate in PEM format to DER format
Function Convert-OpenSSLPemToDer {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$PemFile,

        [Parameter(Mandatory)]
        [String]$DerFile
    )

    $Params = @(
        'x509',
        '-outform', 'der',
        '-in', $PemFile,
        '-out', $DerFile
    )

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Convert a certificate in PEM format to PKCS #12 format
Function Convert-OpenSSLPemToPkcs12 {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKeyFile,

        [Parameter(Mandatory)]
        [String]$PemFile,

        [Parameter(Mandatory)]
        [String]$Pkcs12File,

        [ValidateNotNullOrEmpty()]
        [String]$CaCertsFile,

        [Switch]$LegacyEncryption
    )

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'pkcs12',
            '-export',
            '-inkey', $PrivateKeyFile,
            '-in', $PemFile,
            '-out', $Pkcs12File
        )
    )

    if ($CaCertsFile) {
        $Params.Add('-certfile')
        $Params.Add($CaCertsFile)
    }

    if ($LegacyEncryption) {
        $Params.Add('-legacy')
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params.ToArray() | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Convert a certificate in PKCS #12 format to PEM format
Function Convert-OpenSSLPkcs12ToPem {
    [CmdletBinding(DefaultParameterSetName = 'Both')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12File,

        [Parameter(Mandatory)]
        [String]$PemFile,

        [Parameter(ParameterSetName = 'CertificatesOnly')]
        [Switch]$CertificatesOnly,

        [Parameter(ParameterSetName = 'PrivateKeyOnly')]
        [Switch]$PrivateKeyOnly,

        [Parameter(ParameterSetName = 'PrivateKeyOnly')]
        [Switch]$EncryptKey
    )

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'pkcs12',
            '-in', $Pkcs12File,
            '-out', $PemFile
        )
    )

    if ($PSCmdlet.ParameterSetName -eq 'CertificatesOnly') {
        $Params.Add('-nokeys')
    } elseif ($PSCmdlet.ParameterSetName -eq 'PrivateKeyOnly') {
        $Params.Add('-nocerts')

        if (!$EncryptKey) {
            $Params.Add('-nodes')
        }
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params.ToArray() | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Retrieve the details of a certificate
Function Get-OpenSSLCertificate {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Certificate,

        [String[]]$NameOptions = 'oneline'
    )

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'x509',
            '-in', $Certificate,
            '-noout',
            '-text'
        )
    )

    if ($NameOptions) {
        $Params.Add('-nameopt')
        $Params.Add($NameOptions -join ',')
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params.ToArray() | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Retrieve the details of a certificate signing request
Function Get-OpenSSLCsr {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Csr,

        [String[]]$NameOptions = 'oneline'
    )

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'req',
            '-in', $Csr,
            '-noout',
            '-text',
            '-verify'
        )
    )

    if ($NameOptions) {
        $Params.Add('-nameopt')
        $Params.Add($NameOptions -join ',')
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params.ToArray() | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Retrieve the list of supported ECC curves
Function Get-OpenSSLEccCurves {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param()

    $Params = @(
        'ecparam',
        '-list_curves'
    )

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Retrieve the details of a PKCS #12 certificate
Function Get-OpenSSLPkcs12 {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12
    )

    $Params = @(
        'pkcs12',
        '-in', $Pkcs12,
        '-info'
    )

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Retrieve the details of a private key
Function Get-OpenSSLPrivateKey {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKey
    )

    $Params = @(
        'rsa',
        '-in', $PrivateKey,
        '-check'
    )

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Create a certificate signing request or self-signed certificate
Function New-OpenSSLCertificate {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(ParameterSetName = 'Csr', Mandatory)]
        [Switch]$Csr,

        [Parameter(ParameterSetName = 'SelfSigned', Mandatory)]
        [Switch]$SelfSigned,

        [Parameter(Mandatory)]
        [String]$Name,

        [ValidateLength(1, 64)]
        [String]$CommonName,

        [ValidateLength(1, 64)]
        [String]$EmailAddress,

        [ValidateLength(1, 64)]
        [String]$OrganisationalUnit,

        [ValidateLength(1, 64)]
        [String]$Organisation,

        [ValidateLength(1, 64)]
        [String]$City,

        [ValidateLength(1, 64)]
        [String]$State,

        [ValidatePattern('^[A-Z]{2}$', Options = 'None')]
        [String]$Country,

        [String[]]$AdditionalDomains,
        [IPAddress[]]$IPAddresses,

        [Switch]$NoMatchingSAN,

        [ValidateRange(1, [Int]::MaxValue)]
        [Int]$KeySize,

        [Parameter(ParameterSetName = 'SelfSigned', Mandatory)]
        [ValidateRange(1, [Int]::MaxValue)]
        [Int]$ValidDays = 365,

        [Switch]$EncryptKey,

        [ValidateNotNullOrEmpty()]
        [String]$Config
    )

    if ($PSCmdlet.ParameterSetName -eq 'Csr') {
        $Type = '-new'
        $Out = ('{0}.csr' -f $Name)
    } else {
        $Type = '-x509'
        $Out = ('{0}.cer' -f $Name)
    }

    $KeyOut = '{0}.key' -f $Name

    if ($KeySize) {
        $KeyType = 'rsa:{0}' -f $KeySize
    } else {
        $KeyType = 'rsa'
    }

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'req',
            $Type,
            '-out', $Out,
            '-keyout', $KeyOut,
            '-newkey', $KeyType
        )
    )

    $Subjects = [Collections.Generic.List[String]]::new()
    $SANs = [Collections.Generic.List[String]]::new()

    if ($EmailAddress) {
        $Subjects.Add(('emailAddress={0}' -f $EmailAddress))
    }

    if ($CommonName) {
        $Subjects.Add(('commonName={0}' -f $CommonName))
        if (!$NoMatchingSAN) {
            $SANs.Add(('DNS:{0}' -f $CommonName))
        }
    } else {
        Write-Warning -Message 'No Common Name (CN) was specified so a matching SAN will not be added.'
    }

    if ($OrganisationalUnit) {
        $Subjects.Add(('organizationalUnitName={0}' -f $OrganisationalUnit))
    }

    if ($Organisation) {
        $Subjects.Add(('organizationName={0}' -f $Organisation))
    }

    if ($City) {
        $Subjects.Add(('localityName={0}' -f $City))
    }

    if ($State) {
        $Subjects.Add(('stateOrProvinceName={0}' -f $State))
    }

    if ($Country) {
        $Subjects.Add(('countryName={0}' -f $Country))
    }

    if ($AdditionalDomains.Count -gt 0) {
        foreach ($Domain in $AdditionalDomains) {
            $SANs.Add(('DNS:{0}' -f $Domain))
        }
    }

    if ($IPAddresses.Count -gt 0) {
        foreach ($IPAddress in $IPAddresses) {
            if ($IPAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
                Write-Error -Message ('Provided IP address is not IPv4: {0}' -f $IPAddress)
                return
            }

            $SANs.Add(('IP:{0}' -f $IPAddress))
        }
    }

    if ($Subjects.Count -gt 0) {
        $Subject = '/{0}' -f ($Subjects -join '/')
        $Params.Add('-subj')
        $Params.Add($Subject)

        if ($SANs.Count -gt 0) {
            $SAN = 'subjectAltName = {0}' -f ($SANs -join ', ')
            $Params.Add('-addext')
            $Params.Add($SAN)
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'SelfSigned') {
        $Params.Add('-sha256')
        $Params.Add('-days')
        $Params.Add($ValidDays)
    }

    if (!$EncryptKey) {
        $Params.Add('-nodes')
    }

    if ($Config) {
        $Params.Add('-config')
        $Params.Add($Config)
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params.ToArray() | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

Complete-DotFilesSection
