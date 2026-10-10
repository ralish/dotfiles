$DotFilesSection = @{
    Type    = 'Functions'
    Name    = 'OpenSSL'
    Command = 'openssl'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

#region Certificate creation

# Create a certificate signing request or self-signed certificate
# https://docs.openssl.org/master/man1/openssl-req/
Function Global:New-OpenSSLCertificate {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
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
        [String]$ExistingKeyPath,

        [Parameter(ParameterSetName = 'CsrGenerateKey')]
        [Parameter(ParameterSetName = 'SelfSignedGenerateKey')]
        [ValidateRange(1, 16384)]
        [UInt16]$KeySize,

        [Parameter(ParameterSetName = 'CsrGenerateKey')]
        [Parameter(ParameterSetName = 'SelfSignedGenerateKey')]
        [Switch]$EncryptKey,

        [Parameter(ParameterSetName = 'SelfSignedExistingKey')]
        [Parameter(ParameterSetName = 'SelfSignedGenerateKey')]
        [ValidateRange(1, [UInt32]::MaxValue)]
        [UInt32]$ValidDays = 365,

        [ValidateNotNullOrEmpty()]
        [String]$Config
    )

    Function Get-EscapedRdn {
        [CmdletBinding()]
        [OutputType([String])]
        Param(
            [Parameter(Mandatory)]
            [String]$Rdn
        )

        # Escape "=" and "/" as they are treated as separators
        return $Rdn -replace '=', '\=' -replace '/', '\/'
    }

    $OpenSSLVersion = Get-OpenSSLVersion

    $NewCertArgs = [Collections.Generic.List[String]]::new()
    $NewCertArgs.Add('req')

    if ($PSCmdlet.ParameterSetName -match '^Csr') {
        $NewCertArgs.Add('-new')
        $Out = "${Name}.csr"
    } else {
        $NewCertArgs.Add('-x509')
        $Out = "${Name}.cer"
    }

    $NewCertArgs.Add('-out')
    $NewCertArgs.Add($Out)

    if ($PSCmdlet.ParameterSetName -match 'GenerateKey$') {
        $NewCertArgs.Add('-keyout')
        $NewCertArgs.Add("${Name}.key")

        $NewCertArgs.Add('-newkey')
        if ($KeySize) {
            $NewCertArgs.Add("rsa:${KeySize}")
        } else {
            $NewCertArgs.Add('rsa')
        }

        if (!$EncryptKey) {
            if ($OpenSSLVersion -ge '3.0') {
                $NewCertArgs.Add('-noenc')
            } else {
                $NewCertArgs.Add('-nodes')
            }
        }
    } else {
        $NewCertArgs.Add('-key')
        $NewCertArgs.Add($ExistingKeyPath)
    }

    $Subjects = [Collections.Generic.List[String]]::new()
    $SANs = [Collections.Generic.List[String]]::new()

    if ($EmailAddress) {
        $Subjects.Add("emailAddress=$(Get-EscapedRdn -Rdn $EmailAddress)")
    }

    if ($CommonName) {
        $Subjects.Add("commonName=$(Get-EscapedRdn -Rdn $CommonName)")
        if (!$NoMatchingSAN) {
            $SANs.Add("DNS:${CommonName}")
        }
    } else {
        Write-Warning -Message 'No Common Name (CN) was specified so a matching SAN will not be added.'
    }

    if ($OrganisationalUnit) {
        $Subjects.Add("organizationalUnitName=$(Get-EscapedRdn -Rdn $OrganisationalUnit)")
    }

    if ($Organisation) {
        $Subjects.Add("organizationName=$(Get-EscapedRdn -Rdn $Organisation)")
    }

    if ($City) {
        $Subjects.Add("localityName=$(Get-EscapedRdn -Rdn $City)")
    }

    if ($State) {
        $Subjects.Add("stateOrProvinceName=$(Get-EscapedRdn -Rdn $State)")
    }

    if ($Country) {
        $Subjects.Add("countryName=$(Get-EscapedRdn -Rdn $Country)")
    }

    if ($AdditionalDomains -and $AdditionalDomains.Count -ne 0) {
        foreach ($Domain in $AdditionalDomains) {
            $SANs.Add("DNS:${Domain}")
        }
    }

    if ($IPAddresses -and $IPAddresses.Count -ne 0) {
        foreach ($IPAddress in $IPAddresses) {
            if ($IPAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -and
                $IPAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetworkV6) {
                $ExcMsg = "Provided IP address is neither IPv4 or IPv6: ${IPAddress}"
                $ErrExc = [ArgumentException]::new($ExcMsg, 'IPAddresses')
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $IPAddress)
                $PSCmdlet.ThrowTerminatingError($ErrRec)
            }

            $SANs.Add("IP:${IPAddress}")
        }
    }

    if ($Subjects.Count -ne 0) {
        $Subject = "/$($Subjects -join '/')"
        $NewCertArgs.Add('-subj')
        $NewCertArgs.Add($Subject)
    }

    if ($SANs.Count -ne 0) {
        $SAN = "subjectAltName = $($SANs -join ', ')"
        $NewCertArgs.Add('-addext')
        $NewCertArgs.Add($SAN)
    }

    if ($PSCmdlet.ParameterSetName -match '^SelfSigned') {
        $NewCertArgs.Add('-sha256')
        $NewCertArgs.Add('-days')
        $NewCertArgs.Add([String]$ValidDays)
    }

    if ($Config) {
        $NewCertArgs.Add('-config')
        $NewCertArgs.Add($Config)
    }

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($NewCertArgs | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @NewCertArgs
}

#endregion

#region Certificate information

# Retrieve the details of a certificate
# https://docs.openssl.org/master/man1/openssl-x509/
Function Global:Get-OpenSSLCertificate {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Certificate,

        # https://docs.openssl.org/master/man1/openssl-namedisplay-options/
        [String[]]$NameOptions = 'oneline'
    )

    $GetCertArgs = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'x509'
            '-in', $Certificate
            # Suppress default certificate output
            '-noout'
            # Print the certificate in text form
            '-text'
        )
    )

    if ($NameOptions) {
        $GetCertArgs.Add('-nameopt')
        $GetCertArgs.Add($NameOptions -join ',')
    }

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetCertArgs | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @GetCertArgs
}

# Retrieve the details of a certificate signing request
# https://docs.openssl.org/master/man1/openssl-req/
Function Global:Get-OpenSSLCsr {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$Csr,

        # https://docs.openssl.org/master/man1/openssl-namedisplay-options/
        [String[]]$NameOptions = 'oneline'
    )

    $GetCsrArgs = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'req'
            '-in', $Csr
            # Verify the signature on the request
            '-verify'
            # Suppress default certificate request output
            '-noout'
            # Print the certificate request in text form
            '-text'
        )
    )

    if ($NameOptions) {
        $GetCsrArgs.Add('-nameopt')
        $GetCsrArgs.Add($NameOptions -join ',')
    }

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetCsrArgs | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @GetCsrArgs
}

# Retrieve the details of a PKCS #12 certificate
# https://docs.openssl.org/master/man1/openssl-pkcs12/
Function Global:Get-OpenSSLPkcs12 {
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

    $OpenSSLVersion = Get-OpenSSLVersion

    $GetPkcs12Args = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'pkcs12'
            '-in', $Pkcs12File
            # Print additional information about the PKCS #12 file
            '-info'
        )
    )

    if (!$VerifyOnly) {
        if ($PrivateKeyEncryption) {
            $GetPkcs12Args.Add("-$($PrivateKeyEncryption.ToLower())")
        } else {
            if ($OpenSSLVersion -ge '3.0') {
                $GetPkcs12Args.Add('-noenc')
            } else {
                $GetPkcs12Args.Add('-nodes')
            }
        }
    } else {
        $GetPkcs12Args.Add('-noout')
    }

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetPkcs12Args | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @GetPkcs12Args
}

#endregion

#region Certificate retrieval

# Retrieve a certificate from a SSL/TLS server
# https://docs.openssl.org/master/man1/openssl-s_client/
Function Global:Get-OpenSSLServerCertificate {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
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
            'Postgres', 'Sieve', 'SMTP', 'Telnet', 'XMPP', 'Xmpp-Server'
        )]
        [String]$StartTls,

        [Switch]$KeepStdinOpen
    )

    $GetSvrCertArgs = [Collections.Generic.List[String]]::new(
        [String[]]@(
            's_client'
            '-connect', "${Hostname}:${Port}"
        )
    )

    if ($IpVersion) {
        if ($IpVersion -eq 'IPv4Only') {
            $GetSvrCertArgs.Add('-4')
        } else {
            $GetSvrCertArgs.Add('-6')
        }
    }

    if ($ServerName) {
        $GetSvrCertArgs.Add('-servername')
        $GetSvrCertArgs.Add($ServerName)
    }

    if ($StartTls) {
        $GetSvrCertArgs.Add('-starttls')
        $GetSvrCertArgs.Add($StartTls.ToLower())
    }

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetSvrCertArgs | Add-QuotesToStringWithSpace) -join ' ')"

    # The `s_client` command keeps the connection open for further commands.
    # Piping `$null` will effectively close standard input, gracefully closing
    # the connection after it's established.
    if ($KeepStdinOpen) {
        & openssl @GetSvrCertArgs
    } else {
        $null | & openssl @GetSvrCertArgs
    }
}

#endregion

#region Conversion operations

# Convert a certificate in DER format to PEM format
# https://docs.openssl.org/master/man1/openssl-x509/
Function Global:Convert-OpenSSLDerToPem {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$DerFile,

        [Parameter(Mandatory)]
        [String]$PemFile
    )

    $GetDerToPemArgs = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'x509',
            '-in', $DerFile
            '-inform', 'DER'
            '-out', $PemFile
            '-outform', 'PEM'
        )
    )

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetDerToPemArgs | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @GetDerToPemArgs
}

# Convert a certificate in PEM format to DER format
# https://docs.openssl.org/master/man1/openssl-x509/
Function Global:Convert-OpenSSLPemToDer {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$PemFile,

        [Parameter(Mandatory)]
        [String]$DerFile
    )

    $GetPemToDerArgs = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'x509',
            '-in', $PemFile
            '-inform', 'PEM'
            '-out', $DerFile
            '-outform', 'DER'
        )
    )

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetPemToDerArgs | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @GetPemToDerArgs
}

# Convert a certificate in PEM format to PKCS #12 format
# https://docs.openssl.org/master/man1/openssl-pkcs12/
Function Global:Convert-OpenSSLPemToPkcs12 {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param(
        [Parameter(Mandatory)]
        [String]$PemFile,

        [Parameter(Mandatory)]
        [String]$Pkcs12File,

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

        # Use the legacy mode of operation
        #
        # When *not* set the private key is encrypted with AES256-CBC, as is
        # the certificate unless `-CertificateDesEncryption` is provided.
        #
        # When set the private key is encrypted with 3DES-CBC. The certificate
        # is encrypted with RC2-CBC, if it was enabled in the OpenSSL build,
        # otherwise 3DES-CBC (matching the private key).
        #
        # Windows releases prior to Windows Server 2019 and Windows 10 v1803
        # only support 3DES encryption for PKCS #12 files.
        [Switch]$LegacyEncryption
    )

    $GetPemToPkcs12Args = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'pkcs12'
            '-export'
            '-out', $Pkcs12File
            '-in', $PemFile
        )
    )

    if ($PrivateKeyFile) {
        $GetPemToPkcs12Args.Add('-inkey')
        $GetPemToPkcs12Args.Add($PrivateKeyFile)
    }

    if ($CertsFile) {
        $GetPemToPkcs12Args.Add('-certfile')
        $GetPemToPkcs12Args.Add($CertsFile)
    }

    if ($FriendlyName) {
        $GetPemToPkcs12Args.Add('-name')
        $GetPemToPkcs12Args.Add($FriendlyName)
    }

    if ($CertificateDesEncryption) {
        $GetPemToPkcs12Args.Add('-descert')
    } elseif ($LegacyEncryption) {
        $GetPemToPkcs12Args.Add('-legacy')
    }

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetPemToPkcs12Args | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @GetPemToPkcs12Args
}

# Convert a certificate in PKCS #12 format to PEM format
# https://docs.openssl.org/master/man1/openssl-pkcs12/
Function Global:Convert-OpenSSLPkcs12ToPem {
    [CmdletBinding(DefaultParameterSetName = 'Both')]
    [OutputType([Void], [String[]])]
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

    $OpenSSLVersion = Get-OpenSSLVersion

    $GetPkcs12ToPemArgs = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'pkcs12'
            '-in', $Pkcs12File
            '-out', $PemFile
        )
    )

    if ($PSCmdlet.ParameterSetName -eq 'CertificatesOnly') {
        $GetPkcs12ToPemArgs.Add('-nokeys')
    } elseif ($PSCmdlet.ParameterSetName -eq 'PrivateKeyOnly') {
        $GetPkcs12ToPemArgs.Add('-nocerts')
    }

    if ($PSCmdlet.ParameterSetName -ne 'CertificatesOnly') {
        if ($PrivateKeyEncryption) {
            $GetPkcs12ToPemArgs.Add("-$($PrivateKeyEncryption.ToLower())")
        } else {
            if ($OpenSSLVersion -ge '3.0') {
                $GetPkcs12ToPemArgs.Add('-noenc')
            } else {
                $GetPkcs12ToPemArgs.Add('-nodes')
            }
        }
    }

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetPkcs12ToPemArgs | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @GetPkcs12ToPemArgs
}

#endregion

#region Miscellaneous

# Retrieve the list of supported ECC curves
# https://docs.openssl.org/master/man1/openssl-ecparam/
Function Global:Get-OpenSSLEccCurves {
    [CmdletBinding()]
    [OutputType([Void], [String[]])]
    Param()

    $GetEccCurvesArgs = [Collections.Generic.List[String]]::new(
        [String[]]@(
            'ecparam'
            '-list_curves'
        )
    )

    Write-Host -NoNewline -ForegroundColor 'Green' 'Invoking: '
    Write-Host "openssl $(($GetEccCurvesArgs | Add-QuotesToStringWithSpace) -join ' ')"
    & openssl @GetEccCurvesArgs
}

#endregion

#region Helper functions

# Retrieve the installed version of OpenSSL
# https://docs.openssl.org/master/man1/openssl-version/
Function Global:Get-OpenSSLVersion {
    [CmdletBinding()]
    [OutputType([Version])]
    Param()

    $VersionArgs = 'version', '-v'
    $VersionCmd = "openssl $($VersionArgs -join ' ')"

    $VersionRaw = @(& openssl @VersionArgs) -join ''
    if ($LASTEXITCODE -ne 0) {
        $ExcMsg = "Failed to retrieve OpenSSL version (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $VersionCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($VersionRaw -notmatch '^OpenSSL ([0-9]+\.[0-9]+(\.[0-9]+)?)') {
        $ExcMsg = "Failed to extract OpenSSL version: ${VersionRaw}"
        $ErrExc = [FormatException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ParserError
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $VersionRaw)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    return [Version]$Matches[1]
}

#endregion

Complete-DotFilesSection
