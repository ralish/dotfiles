Write-Verbose -Message '[dotfiles] Configuring aliases ...'

# Some useful aliases
Set-Alias -Name cop     -Value Compare-ObjectProperties
Set-Alias -Name gh      -Value Get-Help
Set-Alias -Name gita    -Value Invoke-GitChildDir
Set-Alias -Name up      -Value Update-Profile
Set-Alias -Name which   -Value Get-Command

# Windows only
if (Test-IsWindows) {
    # Remove the curl alias if the real deal is present
    if (Get-Command -Name curl.exe -ErrorAction Ignore) {
        Remove-Item -Path Alias:\curl -ErrorAction Ignore
    }

    # Remove the sc alias in favour of the sc.exe utility
    if (Get-Command -Name sc.exe -ErrorAction Ignore) {
        Remove-Item -Path Alias:\sc -ErrorAction Ignore
    }
}
