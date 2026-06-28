$DotFilesSection = @{
    Type    = 'Functions'
    Name    = 'OpenSSH'
    Command = 'ssh'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Update OpenSSH configuration
Function Update-OpenSSHConfig {
    [CmdletBinding()]
    [OutputType([Void])]
    Param()

    # Directives introduced in a given OpenSSH version which may need to be
    # removed in the generated configuration if an older version is in use.
    $NewDirectives = @{
        '9.1' = @('RequiredRSASize')
    }

    # OpenSSH outputs its version string on `stderr`. When redirecting `stderr`
    # to `stdout` PowerShell will silently create an error record containing
    # the output. While it's not a terminating error, custom prompt functions
    # often record the error count before and after command execution, with an
    # increase in the count being considered an indicator that the previous
    # command failed. To avoid this function erroneously being shown as having
    # failed when used with such prompts we clear the most recent error record
    # if the error count increased after retrieving the OpenSSH client version.
    try {
        $ErrorCount = $Error.Count
        $VersionArgs = @('-V')
        $VersionCmd = "ssh $($VersionArgs -join ' ')"
        $VersionRaw = & ssh @VersionArgs 2>&1 | Out-String
    } finally {
        if ($Error.Count -eq ($ErrorCount + 1)) {
            $Error.RemoveAt(0)
        }
    }

    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve OpenSSH version (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $VersionCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    if ($VersionRaw -notmatch '^OpenSSH\S+([1-9][0-9]?\.[0-9]{1,2})') {
        $ErrMsg = "Failed to extract OpenSSH version: ${VersionRaw}"
        $ErrExc = [FormatException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ParserError
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'RegexMatchFailed', $ErrCat, $VersionRaw)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $Version = $Matches[1]
    Write-Verbose -Message "Found OpenSSH version: ${Version}"

    $BaseDir = Join-Path -Path $DotFiles -ChildPath 'openssh/.ssh'
    $TemplatesDir = Join-Path -Path $BaseDir -ChildPath 'templates'
    $TemplateFile = Join-Path -Path $TemplatesDir -ChildPath "ssh_config.$($Version -replace '\.')"

    if (!(Test-Path -LiteralPath $TemplateFile -PathType 'Leaf')) {
        $ErrMsg = "No configuration template for OpenSSH version: ${Version}"
        $ErrExc = [IO.FileNotFoundException]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::ObjectNotFound
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PathNotFound', $ErrCat, $TemplateFile)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    # Retrieve supported KEX algorithms for later filtering
    $KexArgs = '-Q', 'kex'
    $KexCmd = "ssh $($KexArgs -join ' ')"
    $SupportedKexAlgorithms = @(& ssh @KexArgs)
    if ($LASTEXITCODE -ne 0) {
        $ErrMsg = "Failed to retrieve supported KEX algorithms (rc: ${LASTEXITCODE})."
        $ErrExc = [Exception]::new($ErrMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidResult
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'NativeCommandFailed', $ErrCat, $KexCmd)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    # Ensure we create the file without a BOM
    $UTF8EncodingNoBom = [Text.UTF8Encoding]::new($false)

    $BannerFile = Join-Path -Path $TemplatesDir -ChildPath 'banner'
    $ConfigFile = Join-Path -Path $BaseDir -ChildPath 'config'
    $ConfigFileTmp = "${ConfigFile}.tmp"

    # Remove any pre-existing temporary file
    Remove-Item -LiteralPath $ConfigFileTmp -ErrorAction 'Ignore'

    try {
        $Banner = @(Get-Content -LiteralPath $BannerFile -ErrorAction 'Stop')
        if ($Banner.Count -ge 3) {
            $BannerLines = [String[]]$Banner[0..($Banner.Count - 2)]
            [IO.File]::AppendAllLines($ConfigFileTmp, $BannerLines, $UTF8EncodingNoBom)
        } elseif ($Banner.Count -gt 0) {
            Write-Warning -Message 'Banner file has fewer than the minimum of 3 lines and will be ignored.'
        }
    } catch {
        $Exc = $PSItem
        switch -Regex ($Exc.FullyQualifiedErrorId) {
            '^PathNotFound,' { Write-Warning -Message "Banner file does not exist and will be skipped: ${BannerFile}" }
            default { $PSCmdlet.WriteError($Exc) }
        }
    }

    try {
        $IncludesDir = Join-Path -Path $BaseDir -ChildPath 'includes'
        $Includes = @(Get-ChildItem -LiteralPath $IncludesDir -File -ErrorAction 'Stop')

        foreach ($Include in $Includes) {
            $Data = @(Get-Content -LiteralPath $Include.FullName -ErrorAction 'Stop')
            if ($Data.Count -ge 3) {
                $IncludeLines = [String[]]($Data[0..($Data.Count - 2)] + '')
                [IO.File]::AppendAllLines($ConfigFileTmp, $IncludeLines, $UTF8EncodingNoBom)
            } elseif ($Data.Count -gt 0) {
                Write-Warning -Message "Included configuration file has fewer than the minimum of 3 lines and will be ignored: $($Include.Name)"
            }
        }

        $Template = [String[]](Get-Content -LiteralPath $TemplateFile -ErrorAction 'Stop')
        [IO.File]::AppendAllLines($ConfigFileTmp, $Template, $UTF8EncodingNoBom)
        $Config = @(Get-Content -LiteralPath $ConfigFileTmp -ErrorAction 'Stop')
    } catch {
        Remove-Item -LiteralPath $ConfigFileTmp -ErrorAction 'Ignore'

        $ErrMsg = "Fatal error building OpenSSH configuration file: $($PSItem.Exception.Message)"
        $ErrExc = [Exception]::new($ErrMsg, $PSItem.Exception)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidOperation
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'OpensshBuildConfigFailed', $ErrCat, $null)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    # OpenSSH for Windows (which is *not* the same as OpenSSH Portable) doesn't
    # support the `sntrup761x25519-sha512@openssh.com` key exchange algorithm.
    # Until it does, we have to remove any usage of it in our configuration
    # template or OpenSSH complains about an unsupported KEX algorithm. This
    # hack is written to ensure we don't remove it when/if support is added.
    # https://github.com/PowerShell/Win32-OpenSSH/issues/1927
    if ($SupportedKexAlgorithms -notcontains 'sntrup761x25519-sha512@openssh.com') {
        for ($i = 0; $i -lt $Config.Count; $i++) {
            if ($Config[$i] -match '^(\s*KexAlgorithms\s+)(\S+)') {
                $KexKey = $Matches[1]
                $KexValues = $Matches[2]
                $KexFiltered = @($KexValues -split ',' | Where-Object { $PSItem -notmatch 'sntrup761x25519-sha512@openssh\.com' })

                if ($KexFiltered.Count -eq 0) {
                    $ErrMsg = 'No KEX algorithms remaining after removal of unsupported "sntrup761x25519-sha512@openssh.com" algorithm.'
                    $ErrExc = [Exception]::new($ErrMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidOperation
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'OpensshBuildConfigFailed', $ErrCat, $Config[$i])
                    $PSCmdlet.ThrowTerminatingError($ErrRec)
                }

                $Config[$i] = "${KexKey}$($KexFiltered -join ',')"
            }
        }
    }

    # Remove configuration directives this OpenSSH version doesn't support
    foreach ($DirectivesVersion in $NewDirectives.Keys) {
        if ([Version]$Version -lt $DirectivesVersion) {
            Write-Verbose -Message "Removing directives for newer OpenSSH version: ${DirectivesVersion}"

            foreach ($Directive in $NewDirectives[$DirectivesVersion]) {
                $ConfigOld = $Config
                $Config = [Collections.Generic.List[String]]::new()

                for ($i = 0; $i -lt $ConfigOld.Count; $i++) {
                    if ($ConfigOld[$i] -notmatch "^\s*${Directive}\s+\S+") {
                        $Config.Add($ConfigOld[$i])
                        continue
                    }

                    # Matched a line to be excluded; walk backwards to remove
                    # comments and new lines which pertain to the directive.
                    for ($LastValidLine = $Config.Count - 1; $LastValidLine -ge 0; $LastValidLine--) {
                        if ($Config[$LastValidLine] -notmatch '^\s*(#.*)?$') { break }
                    }

                    # Note `.Slice()` isn't available on .NET Framework
                    $Config = $Config.GetRange(0, $LastValidLine + 1)
                }
            }
        }
    }

    # Write the final configuration file
    try {
        [IO.File]::WriteAllLines($ConfigFileTmp, [String[]]$Config, $UTF8EncodingNoBom)
    } catch {
        Remove-Item -LiteralPath $ConfigFileTmp -ErrorAction 'Ignore'
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }

    # Overwrite the old configuration file
    try {
        Move-Item -LiteralPath $ConfigFileTmp -Destination $ConfigFile -Force -ErrorAction 'Stop'
    } catch {
        Remove-Item -LiteralPath $ConfigFileTmp -ErrorAction 'Ignore'
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

Complete-DotFilesSection
