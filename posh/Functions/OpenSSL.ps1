Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing OpenSSL functions ...')

# Certificate encoding formats
# - DER:        Distinguished Encoding Rules
# - PEM:        Privacy-Enhanced Mail
# - PKCS #12:   Public-Key Cryptography Standards #12

# Convert a certificate in DER format to PEM format
Function Convert-OpenSSLDerToPem {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$DerFile,

        [Parameter(Mandatory)]
        [String]$PemFile
    )

    & openssl x509 -inform der -in `"$DerFile`" -out `"$PemFile`"
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

    & openssl x509 -outform der -in `"$PemFile`" -out `"$DerFile`"
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

        [String]$CaCertsFile
    )

    if ($CaCertsFile) {
        & openssl pkcs12 -export -inkey `"$PrivateKeyFile`" -in `"$PemFile`" -out `"$Pkcs12File`" -certfile `"$CaCertsFile`"
    } else {
        & openssl pkcs12 -export -inkey `"$PrivateKeyFile`" -in `"$PemFile`" -out `"$Pkcs12File`"
    }
}

# Convert a certificate in PKCS #12 format to PEM format
Function Convert-OpenSSLPkcs12ToPem {
    [CmdletBinding(DefaultParameterSetName='Both')]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12File,

        [Parameter(Mandatory)]
        [String]$PemFile,

        [Parameter(ParameterSetName='CertificatesOnly')]
        [Switch]$CertificatesOnly,

        [Parameter(ParameterSetName='PrivateKeyOnly')]
        [Switch]$PrivateKeyOnly
    )

    if ($CertificatesOnly) {
        & openssl pkcs12 -in `"$Pkcs12File`" -out `"$PemFile`" -nodes -nokeys
    } elseif ($PrivateKeyOnly) {
        & openssl pkcs12 -in `"$Pkcs12File`" -out `"$PemFile`" -nodes -nocerts
    } else {
        & openssl pkcs12 -in `"$Pkcs12File`" -out `"$PemFile`" -nodes
    }
}

# Retrieve the details of a certificate
Function Get-OpenSSLCertificate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Certificate,

        [String[]]$NameOptions=@('oneline')
    )

    $NameOpt = [String]::Join(',', $NameOptions)
    & openssl x509 -in `"$Certificate`" -noout -text -nameopt `"$NameOpt`"
}

# Retrieve the details of a certificate signing request
Function Get-OpenSSLCsr {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Csr,

        [String[]]$NameOptions=@('oneline')
    )

    $NameOpt = [String]::Join(',', $NameOptions)
    & openssl req -in `"$Csr`" -noout -text -verify -nameopt `"$NameOpt`"
}

# Retrieve the details of a PKCS #12 certificate
Function Get-OpenSSLPkcs12 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12
    )

    & openssl rsa -in `"$Pkcs12`" -info
}

# Retrieve the details of a private key
Function Get-OpenSSLPrivateKey {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKey
    )

    & openssl rsa -in `"$PrivateKey`" -check
}

# Create a private key and certificate signing request
Function New-OpenSSLPrivateKeyAndCsr {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKey,

        [Parameter(Mandatory)]
        [String]$Csr,

        [ValidateScript( { $_ -gt 0 } )]
        [Int]$KeySize,

        [Switch]$EncryptKey,

        [ValidateNotNullOrEmpty()]
        [String]$Config
    )

    if ($KeySize) {
        $NewKeyArgs = 'rsa:{0}' -f $KeySize
    } else {
        $NewKeyArgs = 'rsa'
    }

    $Params = @(
        'req',
        '-new',
        '-out',
        ('"{0}"' -f $Csr),
        '-keyout',
        ('"{0}"' -f $PrivateKey),
        '-newkey',
        $NewKeyArgs
    )

    if (!$EncryptKey) {
        $Params += '-nodes'
    }

    if ($Config) {
        $Params += @(
            '-config',
            ('"{0}"' -f $Config)
        )
    }

    Start-Process -FilePath 'openssl' -ArgumentList $Params -NoNewWindow -Wait
}

# Create a private key and self-signed certificate
Function New-OpenSSLSelfSignedCertificate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKey,

        [Parameter(Mandatory)]
        [String]$Certificate,

        [ValidateScript( { $_ -gt 0 } )]
        [Int]$KeySize=2048,

        [ValidateScript( { $_ -gt 0 } )]
        [Int]$ValidDays=365
    )

    & openssl req -out `"$Certificate`" -newkey rsa:$KeySize -nodes -keyout `"$PrivateKey`" -x509 -sha256 -days $ValidDays
}
