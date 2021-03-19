if ($DotFilesShowScriptEntry) {
    Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath)
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Configuring aliases ...')

# Some useful aliases
Set-Alias -Name cop -Value Compare-ObjectProperties
Set-Alias -Name gh -Value Get-Help
Set-Alias -Name gita -Value Invoke-GitChildDir
Set-Alias -Name rdn -Value Resolve-DnsName
Set-Alias -Name up -Value Update-Profile
Set-Alias -Name which -Value Get-Command

# Windows only
if (Test-IsWindows) {
    # Remove the curl alias if the real deal is present
    if (Get-Command -Name curl.exe -ErrorAction Ignore) {
        Remove-Item -LiteralPath Alias:\curl -ErrorAction Ignore
    }

    # Remove the sc alias in favour of the sc.exe utility
    if (Get-Command -Name sc.exe -ErrorAction Ignore) {
        Remove-Item -LiteralPath Alias:\sc -ErrorAction Ignore
    }

    # Remove the wget alias if the real deal is present
    if (Get-Command -Name wget.exe -ErrorAction Ignore) {
        Remove-Item -LiteralPath Alias:\wget -ErrorAction Ignore
    }
}
