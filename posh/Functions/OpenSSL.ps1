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

    & openssl x509 -inform der -in $DerFile -out $PemFile
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

    & openssl x509 -outform der -in $PemFile -out $DerFile
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

    if ($CaCertsFile) {
        & openssl pkcs12 -export -inkey $PrivateKeyFile -in $PemFile -out $Pkcs12File -certfile $CaCertsFile
    } else {
        & openssl pkcs12 -export -inkey $PrivateKeyFile -in $PemFile -out $Pkcs12File
    }
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

    switch ($PSCmdlet.ParameterSetName) {
        'CertificatesOnly' {
            & openssl pkcs12 -in $Pkcs12File -out $PemFile -nodes -nokeys
        }
        'PrivateKeyOnly' {
            & openssl pkcs12 -in $Pkcs12File -out $PemFile -nodes -nocerts
        }
        Default {
            & openssl pkcs12 -in $Pkcs12File -out $PemFile -nodes
        }
    }
}

# Retrieve the details of a certificate
Function Get-OpenSSLCertificate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Certificate,

        [String[]]$NameOptions = 'oneline'
    )

    if ($NameOptions) {
        & openssl x509 -in $Certificate -noout -text -nameopt [String]::Join(',', $NameOptions)
    } else {
        & openssl x509 -in $Certificate -noout -text
    }
}

# Retrieve the details of a certificate signing request
Function Get-OpenSSLCsr {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Csr,

        [String[]]$NameOptions = 'oneline'
    )

    if ($NameOptions) {
        & openssl req -in $Csr -noout -text -verify -nameopt [String]::Join(',', $NameOptions)
    } else {
        & openssl req -in $Csr -noout -text -verify
    }
}

# Retrieve the details of a PKCS #12 certificate
Function Get-OpenSSLPkcs12 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12
    )

    & openssl rsa -in $Pkcs12 -info
}

# Retrieve the details of a private key
Function Get-OpenSSLPrivateKey {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$PrivateKey
    )

    & openssl rsa -in $PrivateKey -check
}

# Create a certificate signing request or self-signed certificate
Function New-OpenSSLCertificate {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName = 'Csr', Mandatory)]
        [String]$Csr,

        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [String]$Certificate,

        [Parameter(Mandatory)]
        [String]$PrivateKey,

        [ValidateRange('Positive')]
        [Int]$KeySize,

        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [ValidateRange('Positive')]
        [Int]$ValidDays = 365,

        [Switch]$EncryptKey,

        [ValidateNotNullOrEmpty()]
        [String]$Config
    )

    if ($PSCmdlet.ParameterSetName -eq 'Csr') {
        $Type = '-new'
        $Out = $Csr
    } else {
        $Type = '-x509'
        $Out = $Certificate
    }

    $Params = @(
        'req',
        $Type,
        '-out', $Out,
        '-keyout', $PrivateKey
    )

    if ($KeySize) {
        $Params += @('-newkey', 'rsa:{0}' -f $KeySize)
    } else {
        $Params += @('-newkey', 'rsa')
    }

    if ($PSCmdlet.ParameterSetName -eq 'Certificate') {
        $Params += @('-sha256', '-days', $ValidDays)
    }

    if (!$EncryptKey) {
        $Params += '-nodes'
    }

    if ($Config) {
        $Params += @('-config', $Config)
    }

    & openssl @Params
}
