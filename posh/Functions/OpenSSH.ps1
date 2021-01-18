if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing OpenSSH functions ...')

# Update our OpenSSH configuration
Function Update-OpenSSHConfig {
    [CmdletBinding()]
    Param()

    $BaseDir = Join-Path -Path $DotFilesPath -ChildPath 'openssh/.ssh'
    $IncludesDir = Join-Path -Path $BaseDir -ChildPath 'includes'
    $TemplatesDir = Join-Path -Path $BaseDir -ChildPath 'templates'

    $ConfigFile = Join-Path -Path $BaseDir -ChildPath 'config'
    $BannerFile = Join-Path -Path $TemplatesDir -ChildPath 'banner'
    $TemplateFile = Join-Path -Path $TemplatesDir -ChildPath 'ssh_config.72'

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
