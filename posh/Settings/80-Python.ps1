$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'Python'
    Command = @('python')
}

if (!(Start-DotFilesSection @DotFilesSection)) {
    Complete-DotFilesSection
    return
}

# Disable venv activation modifying the prompt if we're using oh-my-posh
if (Get-Command -Name 'oh-my-posh' -ErrorAction Ignore) {
    $env:VIRTUAL_ENV_DISABLE_PROMPT = 'true'
}

Complete-DotFilesSection
