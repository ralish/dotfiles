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
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params | Add-QuotesToStringWithSpace)))
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
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params | Add-QuotesToStringWithSpace)))
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
        [String]$CaCertsFile
    )

    $Params = [Collections.ArrayList]::new(
        @(
            'pkcs12',
            '-export',
            '-inkey', $PrivateKeyFile,
            '-in', $PemFile,
            '-out', $Pkcs12File,
            '-nodes'
        )
    )

    if ($CaCertsFile) {
        $null = $Params.Add('-certfile')
        $null = $Params.Add($CaCertsFile)
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params.ToArray() | Add-QuotesToStringWithSpace)))
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
        [Switch]$PrivateKeyOnly
    )

    $Params = [Collections.ArrayList]::new(
        @(
            'pkcs12',
            '-in', $Pkcs12File,
            '-out', $PemFile,
            '-nodes'
        )
    )

    if ($PSCmdlet.ParameterSetName -eq 'CertificatesOnly') {
        $null = $Params.Add('-nokeys')
    } elseif ($PSCmdlet.ParameterSetName -eq 'PrivateKeyOnly') {
        $null = $Params.Add('-nocerts')
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params.ToArray() | Add-QuotesToStringWithSpace)))
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

    $Params = [Collections.ArrayList]::new(
        @(
            'x509',
            '-in', $Certificate,
            '-noout',
            '-text'
        )
    )

    if ($NameOptions) {
        $null = $Params.Add('-nameopt')
        $null = $Params.Add([String]::Join(',', $NameOptions))
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params.ToArray() | Add-QuotesToStringWithSpace)))
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

    $Params = [Collections.ArrayList]::new(
        @(
            'req',
            '-in', $Csr,
            '-noout',
            '-text',
            '-verify'
        )
    )

    if ($NameOptions) {
        $null = $Params.Add('-nameopt')
        $null = $Params.Add([String]::Join(',', $NameOptions))
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params.ToArray() | Add-QuotesToStringWithSpace)))
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
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params | Add-QuotesToStringWithSpace)))
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
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params | Add-QuotesToStringWithSpace)))
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

        [ValidateRange('Positive')]
        [Int]$KeySize,

        [Parameter(ParameterSetName = 'SelfSigned', Mandatory)]
        [ValidateRange('Positive')]
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

    $Params = [Collections.ArrayList]::new(
        @(
            'req',
            $Type,
            '-out', $Out,
            '-keyout', $KeyOut,
            '-newkey', $KeyType
        )
    )

    if ($CommonName) {
        $Subject = '/CN={0}' -f $CommonName
        $null = $Params.Add('-subj')
        $null = $Params.Add($Subject)

        if (!$NoMatchingSAN) {
            $SAN = 'subjectAltName = DNS:{0}' -f $CommonName
            $null = $Params.Add('-addext')
            $null = $Params.Add($SAN)
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'SelfSigned') {
        $null = $Params.Add('-sha256')
        $null = $Params.Add('-days')
        $null = $Params.Add($ValidDays)
    }

    if (!$EncryptKey) {
        $null = $Params.Add('-nodes')
    }

    if ($Config) {
        $null = $Params.Add('-config')
        $null = $Params.Add($Config)
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f [String]::Join(' ', ($Params.ToArray() | Add-QuotesToStringWithSpace)))
    & openssl @Params
}
