Start-DotFilesSection -Type 'Functions' -Name 'OpenSSL'

#region Certificate creation

# Create a certificate signing request or self-signed certificate
# https://docs.openssl.org/master/man1/openssl-req/
Function New-OpenSSLCertificate {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(ParameterSetName = 'CsrGenerateKey', Mandatory)]
        [Parameter(ParameterSetName = 'CsrExistingKey', Mandatory)]
        [Switch]$Csr,

        [Parameter(ParameterSetName = 'SelfSignedGenerateKey', Mandatory)]
        [Parameter(ParameterSetName = 'SelfSignedExistingKey', Mandatory)]
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

        [Parameter(ParameterSetName = 'CsrExistingKey', Mandatory)]
        [Parameter(ParameterSetName = 'SelfSignedExistingKey', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ExistingKeyPath,

        [Parameter(ParameterSetName = 'CsrGenerateKey')]
        [Parameter(ParameterSetName = 'SelfSignedGenerateKey')]
        [ValidateRange(1, [Int]::MaxValue)]
        [Int]$KeySize,

        [Parameter(ParameterSetName = 'CsrGenerateKey')]
        [Parameter(ParameterSetName = 'SelfSignedGenerateKey')]
        [Switch]$EncryptKey,

        [Parameter(ParameterSetName = 'SelfSignedExistingKey')]
        [Parameter(ParameterSetName = 'SelfSignedGenerateKey')]
        [ValidateRange(1, [Int]::MaxValue)]
        [Int]$ValidDays = 365,

        [ValidateNotNullOrEmpty()]
        [String]$Config
    )

    Test-CommandAvailable -Name 'openssl'
    $OpenSSLVersion = Get-OpenSSLVersion

    $Params = [Collections.Generic.List[String]]::new()
    $Params.Add('req')

    if ($PSCmdlet.ParameterSetName -match '^Csr') {
        $Params.Add('-new')
        $Out = '{0}.csr' -f $Name
    } else {
        $Params.Add('-x509')
        $Out = '{0}.cer' -f $Name
    }

    $Params.Add('-out')
    $Params.Add($Out)

    if ($PSCmdlet.ParameterSetName -match 'GenerateKey$') {
        $Params.Add('-keyout')
        $Params.Add(('{0}.key' -f $Name))

        $Params.Add('-newkey')
        if ($KeySize) {
            $Params.Add(('rsa:{0}' -f $KeySize))
        } else {
            $Params.Add('rsa')
        }

        if (!$EncryptKey) {
            if ($OpenSSLVersion -ge '3.0') {
                $Params.Add('-noenc')
            } else {
                $Params.Add('-nodes')
            }
        }
    } else {
        $Params.Add('-key')
        $Params.Add($ExistingKeyPath)
    }

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
            if ($IPAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -and
                $IPAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetworkV6) {
                Write-Error -Message ('Provided IP address is neither IPv4 or IPv6: {0}' -f $IPAddress)
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

    if ($PSCmdlet.ParameterSetName -match '^SelfSigned') {
        $Params.Add('-sha256')
        $Params.Add('-days')
        $Params.Add($ValidDays)
    }

    if ($Config) {
        $Params.Add('-config')
        $Params.Add($Config)
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params.ToArray() | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

#endregion

#region Certificate information

# Retrieve the details of a certificate
# https://docs.openssl.org/master/man1/openssl-x509/
Function Get-OpenSSLCertificate {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Certificate,

        # https://docs.openssl.org/master/man1/openssl-namedisplay-options/
        [String[]]$NameOptions = 'oneline'
    )

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'x509',
            '-in', $Certificate,
            # Suppress default certificate output
            '-noout',
            # Print the certificate in text form
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
# https://docs.openssl.org/master/man1/openssl-req/
Function Get-OpenSSLCsr {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Csr,

        # https://docs.openssl.org/master/man1/openssl-namedisplay-options/
        [String[]]$NameOptions = 'oneline'
    )

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'req',
            '-in', $Csr,
            # Verify the self-signature on the request
            '-verify',
            # Suppress default certificate request output
            '-noout',
            # Print the certificate request in text form
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

# Retrieve the details of a PKCS #12 certificate
# https://docs.openssl.org/master/man1/openssl-pkcs12/
Function Get-OpenSSLPkcs12 {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12File,

        [ValidateSet(
            'AES128', 'AES192', 'AES256',
            'ARIA128', 'ARIA192', 'ARIA256',
            'CAMELLIA128', 'CAMELLIA192', 'CAMELLIA256',
            'DES', 'DES3', # DevSkim: ignore DS106863
            'IDEA'
        )]
        [String]$PrivateKeyEncryption,

        # Inhibits all credential prompts except for the initial import. This
        # will verify the PKCS #12 file but not output its decrypted contents.
        [Switch]$VerifyOnly
    )

    Test-CommandAvailable -Name 'openssl'
    $OpenSSLVersion = Get-OpenSSLVersion

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'pkcs12',
            '-in', $Pkcs12File,
            # Print additional information about the PKCS #12 file
            '-info'
        )
    )

    if (!$VerifyOnly) {
        if ($PrivateKeyEncryption) {
            $Params.Add(('-{0}' -f $PrivateKeyEncryption.ToLower()))
        } else {
            if ($OpenSSLVersion -ge '3.0') {
                $Params.Add('-noenc')
            } else {
                $Params.Add('-nodes')
            }
        }
    } else {
        $Params.Add('-noout')
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

#endregion

#region Certificate retrieval

# Retrieve a certificate from a SSL/TLS server
# https://docs.openssl.org/master/man1/openssl-s_client/
Function Get-OpenSSLServerCertificate {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory)]
        [String]$Hostname,

        [UInt16]$Port = 443,

        [ValidateSet('IPv4Only', 'IPv6Only')]
        [String]$IpVersion,

        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

        [ValidateSet(
            'FTP', 'IMAP', 'IRC', 'LDAP', 'LMTP', 'MySQL', 'NNTP', 'POP3',
            'Postgres', 'Sieve', 'SMTP', 'XMPP', 'XmppServer'
        )]
        [String]$StartTls,

        [Switch]$KeepStdinOpen
    )

    $Params = @(
        's_client',
        '-connect', ('{0}:{1}' -f $Hostname, $Port)
    )

    if ($IpVersion) {
        if ($IpVersion -eq 'IPv4Only') {
            $Params.Add('-4')
        } else {
            $Params.Add('-6')
        }
    }

    if ($ServerName) {
        $Params.Add('-servername')
        $Params.Add($ServerName)
    }

    if ($StartTls) {
        $Params.Add('-starttls')
        $Params.Add($StartTls.ToLower())
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))

    # The s_client command keeps the connection open in anticipation of further
    # commands. Piping $null will effectively close standard input, gracefully
    # closing the connection after it's established.
    if ($KeepStdinOpen) {
        & openssl @Params
    } else {
        $null | & openssl @Params
    }
}


#endregion

#region Conversion operations

# Convert a certificate in DER format to PEM format
# https://docs.openssl.org/master/man1/openssl-x509/
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
        '-in', $DerFile,
        '-inform', 'DER',
        '-out', $PemFile,
        '-outform', 'PEM'
    )

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Convert a certificate in PEM format to DER format
# https://docs.openssl.org/master/man1/openssl-x509/
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
        '-in', $PemFile,
        '-inform', 'PEM',
        '-out', $DerFile,
        '-outform', 'DER'
    )

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Convert a certificate in PEM format to PKCS #12 format
# https://docs.openssl.org/master/man1/openssl-pkcs12/
Function Convert-OpenSSLPemToPkcs12 {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12File,

        [Parameter(Mandatory)]
        [String]$PemFile,

        # Path to private key when not present in the PEM file
        [ValidateNotNullOrEmpty()]
        [String]$PrivateKeyFile,

        # Path to a file with extra certificates to include
        [ValidateNotNullOrEmpty()]
        [String]$CertsFile,

        # A "friendly" name which can be displayed by software importing or
        # otherwise managing the certificate and private key.
        [ValidateNotNullOrEmpty()]
        [String]$FriendlyName,

        # Encrypt the certificate using 3DES-CBC instead of AES256-CBC
        [Switch]$CertificateDesEncryption,

        # Use the legacy made of operation
        #
        # When *not* set, the private key is encrypted with AES256-CBC, as is
        # the certificate unless -CertificateDesEncryption is provided.
        #
        # When set, the private key is encrypted with 3DES-CBC. The certificate
        # is encrypted with RC2-CBC, if it was enabled in the OpenSSL build,
        # otherwise 3DES-CBC (matching the private key).
        #
        # Note that Windows releases prior to Windows Server 2019 and Windows
        # 10, version 1803 only support 3DES encryption for PKCS #12 files.
        [Switch]$LegacyEncryption
    )

    $Params = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'pkcs12',
            '-export',
            '-out', $Pkcs12File,
            '-in', $PemFile
        )
    )

    if ($PrivateKeyFile) {
        $Params.Add('-inkey')
        $Params.Add($PrivateKeyFile)
    }

    if ($CertsFile) {
        $Params.Add('-certfile')
        $Params.Add($CertsFile)
    }

    if ($FriendlyName) {
        $Params.Add('-name')
        $Params.Add($FriendlyName)
    }

    if ($CertificateDesEncryption) {
        $Params.Add('-descert')
    } elseif ($LegacyEncryption) {
        $Params.Add('-legacy')
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params.ToArray() | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

# Convert a certificate in PKCS #12 format to PEM format
# https://docs.openssl.org/master/man1/openssl-pkcs12/
Function Convert-OpenSSLPkcs12ToPem {
    [CmdletBinding(DefaultParameterSetName = 'Both')]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Pkcs12File,

        [Parameter(Mandatory)]
        [String]$PemFile,

        [Parameter(ParameterSetName = 'Both')]
        [Parameter(ParameterSetName = 'PrivateKeyOnly')]
        [ValidateSet(
            'AES128', 'AES192', 'AES256',
            'ARIA128', 'ARIA192', 'ARIA256',
            'CAMELLIA128', 'CAMELLIA192', 'CAMELLIA256',
            'DES', 'DES3', # DevSkim: ignore DS106863
            'IDEA'
        )]
        [String]$PrivateKeyEncryption,

        [Parameter(ParameterSetName = 'CertificatesOnly')]
        [Switch]$CertificatesOnly,

        [Parameter(ParameterSetName = 'PrivateKeyOnly')]
        [Switch]$PrivateKeyOnly
    )

    Test-CommandAvailable -Name 'openssl'
    $OpenSSLVersion = Get-OpenSSLVersion

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
    }

    if ($PSCmdlet.ParameterSetName -ne 'CertificatesOnly') {
        if ($PrivateKeyEncryption) {
            $Params.Add(('-{0}' -f $PrivateKeyEncryption.ToLower()))
        } else {
            if ($OpenSSLVersion -ge '3.0') {
                $Params.Add('-noenc')
            } else {
                $Params.Add('-nodes')
            }
        }
    }

    Write-Host -NoNewline -ForegroundColor Green 'Invoking: '
    Write-Host ('openssl {0}' -f (($Params.ToArray() | Add-QuotesToStringWithSpace) -join ' '))
    & openssl @Params
}

#endregion

#region Miscellaneous

# Retrieve the list of supported ECC curves
# https://docs.openssl.org/master/man1/openssl-ecparam/
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

#endregion

#region Helper functions

# Retrieve the installed version of OpenSSL
# https://docs.openssl.org/master/man1/openssl-version/
Function Get-OpenSSLVersion {
    [CmdletBinding()]
    [OutputType([Version])]
    Param()

    $OpenSSLVersionRaw = (& openssl version -v) -join [String]::Empty
    if ($OpenSSLVersionRaw -notmatch '^OpenSSL ([0-9]+\.[0-9]+(\.[0-9]+)?)') {
        throw 'Unable to determine OpenSSL version.'
    }

    return [Version]$Matches[1]
}

#endregion

Complete-DotFilesSection
