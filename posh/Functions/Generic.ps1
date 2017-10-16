# Convert a string to Base64 form
Function ConvertTo-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$String
    )

    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}

# Convert a string from Base64 form
Function ConvertFrom-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$String
    )

    [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($String))
}

# Watch an Event Log (similar to Unix "tail")
# Slightly improved from: http://stackoverflow.com/questions/15262196/powershell-tail-windows-event-log-is-it-possible
Function Get-EventLogTail {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$EventLog
    )

    $IndexOld = (Get-EventLog -LogName $EventLog -Newest 1).Index
    do {
        Start-Sleep -Seconds 1
        $IndexNew = (Get-EventLog -LogName $EventLog -Newest 1).Index
        if ($IndexNew -ne $IndexOld) {
            Get-EventLog -LogName $EventLog -Newest ($IndexNew - $IndexOld) | Sort-Object -Property Index
            $IndexOld = $IndexNew
        }
    } while ($true)
}

# Helper function to call MKLINK via cmd.exe
Function mklink {
    & $env:ComSpec /c mklink $args
}
