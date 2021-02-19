if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing OpenSSH functions ...')

# Update OpenSSH configuration
Function Update-OpenSSHConfig {
    [CmdletBinding()]
    Param()

    if (!(Get-Command -Name ssh -ErrorAction Ignore)) {
        Write-Error -Message 'Unable to locate ssh executable.'
        return
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

    if (!(Test-Path -Path $TemplateFile)) {
        Write-Error -Message ('No configuration template for OpenSSH version: {0}' -f $Version)
        return
    }

    $IncludesDir = Join-Path -Path $BaseDir -ChildPath 'includes'
    $ConfigFile = Join-Path -Path $BaseDir -ChildPath 'config'
    $BannerFile = Join-Path -Path $TemplatesDir -ChildPath 'banner'

    # Make sure we create the file without a BOM
    [IO.File]::WriteAllLines($ConfigFile, '')

    $Banner = Get-Content -LiteralPath $BannerFile
    Add-Content -Path $ConfigFile -Value $Banner[0..($Banner.Length - 2)]

    $Includes = Get-ChildItem -LiteralPath $IncludesDir -File | Where-Object { $_.Length -gt 0 }
    foreach ($Include in $Includes) {
        $Data = Get-Content -LiteralPath $Include.FullName
        Add-Content -Path $ConfigFile -Value $Data[0..($Data.Length - 2)]
    }

    $Template = Get-Content -LiteralPath $TemplateFile
    Add-Content -Path $ConfigFile -Value $Template[0..($Template.Length - 2)]
}
