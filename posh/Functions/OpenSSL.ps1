if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing OpenSSL functions ...')

# Convert a certificate in DER format to PEM format
Function Convert-OpenSSLDerToPem {
    [CmdletBinding()]
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

# Retrieve the details of a PKCS #12 certificate
Function Get-OpenSSLPkcs12 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12
    )

    $Params = @(
        'rsa',
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
    Param(
        [Parameter(ParameterSetName = 'Csr', Mandatory)]
        [Switch]$Csr,

        [Parameter(ParameterSetName = 'SelfSigned', Mandatory)]
        [Switch]$SelfSigned,

        [Parameter(Mandatory)]
        [String]$Name,

        [ValidateNotNullOrEmpty()]
        [String]$CommonName,

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

    if ($CommonName) {
        $Subject = '/CN={0}' -f $CommonName
        $Params.Add('-subj')
        $Params.Add($Subject)

        if (!$NoMatchingSAN) {
            $SAN = 'subjectAltName = DNS:{0}' -f $CommonName
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
