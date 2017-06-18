# Convert a string to Base64 form
Function ConvertTo-Base64 {
    Param(
        [Parameter(Mandatory)]
        [String]$String
    )

    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}


# Convert a string from Base64 form
Function ConvertFrom-Base64 {
    Param(
        [Parameter(Mandatory)]
        [String]$String
    )

    [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($String))
}


# Watch a Windows Event Log (in a similar fashion to "tail")
# Slightly improved from: http://stackoverflow.com/questions/15262196/powershell-tail-windows-event-log-is-it-possible
Function Get-EventLogTail {
    Param(
        [Parameter(Mandatory)]
        [String]$EventLog
    )

    $IndexOld = (Get-EventLog -LogName $EventLog -Newest 1).Index
    do {
        Start-Sleep -Seconds 1
        $IndexNew = (Get-EventLog -LogName $EventLog -Newest 1).Index
        Get-EventLog -LogName $EventLog -Newest ($IndexNew - $IndexOld) | Sort-Object -Property Index
        $IndexOld = $IndexNew
    } while ($true)
}


# The MKLINK command is actually part of the Command Processor (cmd.exe)
# So we have a quick and dirty function below to invoke it via PowerShell
Function mklink {
    & "$env:ComSpec" /c mklink $args
}
