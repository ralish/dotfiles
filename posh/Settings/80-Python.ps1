# Python
# https://www.python.org/

$DotFilesSection = @{
    Type    = 'Settings'
    Name    = 'Python'
    Command = 'python'
}

if (!(Start-DotFilesSection @DotFilesSection)) { Complete-DotFilesSection; return }

# Disable `venv` activation modifying the prompt when using Oh My Posh
if (Test-Path -LiteralPath 'Variable:\_ompExecutable') {
    $Env:VIRTUAL_ENV_DISABLE_PROMPT = 'true'
}

Complete-DotFilesSection
