# Convert a text file to the given encoding
Function ConvertTo-TextEncoding {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.FileInfo]$File,

        [ValidateSet('ASCII', 'UTF7', 'UTF8', 'UTF16', 'UTF16BE', 'UTF32')]
        [String]$Encoding='UTF8'
    )

    switch ($Encoding) {
        ASCII       { $Encoder = [Text.Encoding]::ASCII }
        UTF7        { $Encoder = [Text.Encoding]::UTF7 }
        UTF8        { $Encoder = [Text.Encoding]::UTF8 }
        UTF16       { $Encoder = [Text.Encoding]::Unicode }
        UTF16BE     { $Encoder = [Text.Encoding]::BigEndianUnicode }
        UTF32       { $Encoder = [Text.Encoding]::UTF32 }
    }

    $Content = Get-Content -Path $File

    Write-Verbose -Message ('Converting to {0}: {1}' -f $Encoding, $File.Name)
    [IO.File]::WriteAllLines($File.FullName, $Content, $Encoder)
}

# Compare the properties of two objects
# Via: https://blogs.technet.microsoft.com/janesays/2017/04/25/compare-all-properties-of-two-objects-in-windows-powershell/
Function Compare-ObjectProperties {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [PSObject]$ReferenceObject,

        [Parameter(Mandatory)]
        [PSObject]$DifferenceObject
    )

    $ObjProps = @()
    $ObjProps += $ReferenceObject | Get-Member -MemberType Property, NoteProperty | Select-Object -ExpandProperty Name
    $ObjProps += $DifferenceObject | Get-Member -MemberType Property, NoteProperty | Select-Object -ExpandProperty Name
    $ObjProps = $ObjProps | Sort-Object | Select-Object -Unique

    $ObjDiffs = @()
    foreach ($Property in $ObjProps) {
        $Diff = Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Property $Property
        if ($Diff) {
            $DiffProps = @{
                PropertyName=$Property
                RefValue=($Diff | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty $($Property))
                DiffValue=($Diff | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty $($Property))
            }
            $ObjDiffs += New-Object -TypeName PSObject -Property $DiffProps
        }
    }

    if ($ObjDiffs) {
        return ($ObjDiffs | Select-Object -Property PropertyName, RefValue, DiffValue)
    }
}

# Convert a string from Base64 form
Function ConvertFrom-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [String]$String
    )

    [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($String))
}

# Convert a string from URL encoded form
Function ConvertFrom-URLEncoded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [String]$String
    )

    [Net.WebUtility]::UrlDecode($String)
}

# Convert a string to Base64 form
Function ConvertTo-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNull()]
        [String]$String
    )

    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}

# Convert a string to URL encoded form
Function ConvertTo-URLEncoded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [String]$String
    )

    [Net.WebUtility]::UrlEncode($String)
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
