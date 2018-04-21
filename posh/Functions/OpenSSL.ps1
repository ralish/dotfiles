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

Function Convert-OpenSSLPkcs12ToPem {
    [CmdletBinding()]
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

Function Get-OpenSSLCertificate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Certificate
    )

    & openssl x509 -in `"$Certificate`" -noout -text
}

Function Get-OpenSSLCsr {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Csr
    )

    & openssl req -in `"$Csr`" -noout -text -verify
}

Function Get-OpenSSLPkcs12 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12
    )

    & openssl rsa -in `"$Pkcs12`" -info
}

Function Get-OpenSSLPrivateKey {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKey
    )

    & openssl rsa -in `"$PrivateKey`" -check
}

Function New-OpenSSLPrivateKeyAndCsr {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKey,

        [Parameter(Mandatory)]
        [String]$Csr,

        [ValidateScript({$_ -gt 0})]
        [Int]$KeySize=2048
    )

    & openssl req -out `"$Csr`" -new -newkey rsa:$KeySize -nodes -keyout `"$PrivateKey`"
}

Function New-OpenSSLSelfSignedCertificate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKey,

        [Parameter(Mandatory)]
        [String]$Certificate,

        [ValidateScript({$_ -gt 0})]
        [Int]$KeySize=2048,

        [ValidateScript({$_ -gt 0})]
        [Int]$ValidDays=365
    )

    & openssl req -out `"$Certificate`" -newkey rsa:$KeySize -nodes -keyout `"$PrivateKey`" -x509 -sha256 -days $ValidDays
}
