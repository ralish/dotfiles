Start-DotFilesSection -Type 'Functions' -Name 'OpenSSH'

# Update OpenSSH configuration
Function Update-OpenSSHConfig {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    if (!(Get-Command -Name 'ssh' -ErrorAction Ignore)) {
        throw 'Unable to locate ssh executable.'
    }

    # Directives introduced in a given OpenSSH version which may need to be
    # removed in the generated configuration if an older version is in use.
    $NewDirectives = @{
        '9.1' = @('RequiredRSASize')
    }

    # OpenSSH outputs its version string on stderr. When redirecting stderr to
    # stdout PowerShell silently creates an error record containing the output.
    # While it's not a terminating error, custom prompt functions often record
    # the error count before and after command execution, with an increase in
    # the count being considered an indicator that the previous command failed.
    #
    # To avoid this function erroneously being shown as having failed when used
    # with such prompts, clear the most recent error record if the error count
    # increased after retrieving the OpenSSH client version string.
    $ErrorCount = $Error.Count
    $VersionRaw = & ssh -V 2>&1
    if ($Error.Count -eq ++$ErrorCount) {
        $Error.RemoveAt(0)
    }

    if ($VersionRaw -match '^OpenSSH\S+([0-9]\.[0-9])') {
        $Version = $Matches[1]
        Write-Verbose -Message ('Found OpenSSH version: {0}' -f $Version)
    } else {
        Write-Error -Message ('Unable to determine OpenSSH version: {0}' -f $VersionRaw)
    }

    $BaseDir = Join-Path -Path $DotFilesPath -ChildPath 'openssh/.ssh'
    $TemplatesDir = Join-Path -Path $BaseDir -ChildPath 'templates'
    $TemplateFile = Join-Path -Path $TemplatesDir -ChildPath ('ssh_config.{0}' -f $Version.Replace('.', [String]::Empty))

    if (!(Test-Path -LiteralPath $TemplateFile)) {
        Write-Error -Message ('No configuration template for OpenSSH version: {0}' -f $Version)
        return
    }

    $IncludesDir = Join-Path -Path $BaseDir -ChildPath 'includes'
    $BannerFile = Join-Path -Path $TemplatesDir -ChildPath 'banner'
    $ConfigFile = Join-Path -Path $BaseDir -ChildPath 'config'
    $ConfigFileTmp = '{0}.tmp' -f $ConfigFile

    $Banner = Get-Content -LiteralPath $BannerFile
    # Make sure we create the file without a BOM
    $UTF8EncodingNoBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllLines($ConfigFileTmp, $Banner[0..($Banner.Count - 2)], $UTF8EncodingNoBom)

    $Includes = Get-ChildItem -LiteralPath $IncludesDir -File | Where-Object Length
    foreach ($Include in $Includes) {
        $Data = Get-Content -LiteralPath $Include.FullName
        Add-Content -LiteralPath $ConfigFileTmp -Value $Data[0..($Data.Count - 2)]
        Add-Content -LiteralPath $ConfigFileTmp -Value ([String]::Empty)
    }

    $Template = Get-Content -LiteralPath $TemplateFile
    Add-Content -LiteralPath $ConfigFileTmp -Value $Template[0..($Template.Count - 1)]
    $Config = Get-Content -LiteralPath $ConfigFileTmp

    # OpenSSH for Windows (which is not the same as OpenSSH Portable) doesn't
    # support the sntrup761x25519-sha512@openssh.com key exchange algorithm.
    # Until it does, we have to remove any usage of it in our configuration
    # template or OpenSSH complains about an unsupported KEX algorithm. This
    # hack is written to ensure we don't remove it when/if support is added.
    #
    # See: https://github.com/PowerShell/Win32-OpenSSH/issues/1927
    $SupportedKexAlgorithms = & ssh -Q kex
    if ($SupportedKexAlgorithms -notcontains 'sntrup761x25519-sha512@openssh.com') {
        for ($i = 0; $i -lt $Config.Count; $i++) {
            if ($Config[$i] -match '^\s*KexAlgorithms\s+\S+') {
                $Config[$i] = $Config[$i] -replace 'sntrup761x25519-sha512@openssh\.com,?'
            }
        }
    }

    $ConfigCur = [Collections.Generic.List[String]]::new()
    foreach ($Line in $Config) {
        $ConfigCur.Add($Line)
    }

    # Remove configuration directives this OpenSSH version doesn't support
    foreach ($DirectivesVersion in $NewDirectives.Keys) {
        if ([Version]$Version -lt $DirectivesVersion) {
            Write-Verbose -Message ('Removing directives for newer OpenSSH version: {0}' -f $DirectivesVersion)

            foreach ($Directive in $NewDirectives[$DirectivesVersion]) {
                $ConfigNew = [Collections.Generic.List[String]]::new()

                for ($i = 0; $i -lt $ConfigCur.Count; $i++) {
                    if ($ConfigCur[$i] -notmatch "^\s*$Directive\s+\S+") {
                        $ConfigNew.Add($ConfigCur[$i])
                        continue
                    }

                    # Matched a line to be excluded; walk backwards to remove
                    # comments and new lines which to pertain to the directive.
                    for ($LastValidLine = $i - 1; $LastValidLine -ge 0; $LastValidLine--) {
                        if ($ConfigCur[$LastValidLine] -notmatch '^\s*(#.*)?$') { break }
                    }

                    $ConfigNew = $ConfigNew.Slice(0, $LastValidLine + 1)
                }

                $ConfigCur.Clear()
                $ConfigCur = $ConfigNew
            }
        }
    }

    # Write the final configuration file content and move it into place
    $UTF8EncodingNoBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllLines($ConfigFileTmp, $ConfigCur, $UTF8EncodingNoBom)
    Move-Item -Path $ConfigFileTmp -Destination $ConfigFile -Force
}

Complete-DotFilesSection
