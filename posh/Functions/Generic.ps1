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

# Convert a text file to the given encoding
Function ConvertTo-TextEncoding {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [IO.FileInfo[]]$File,

        [ValidateSet('ASCII', 'UTF7', 'UTF8', 'UTF16', 'UTF16BE', 'UTF32', 'UTF32BE')]
        [String]$Encoding='UTF8',

        [Switch]$ByteOrderMark
    )

    Begin {
        switch ($Encoding) {
            ASCII       { $Encoder = New-Object -TypeName Text.ASCIIEncoding }
            UTF7        { $Encoder = New-Object -TypeName Text.UTF7Encoding }
            UTF8        { $Encoder = New-Object -TypeName Text.UTF8Encoding -ArgumentList ($ByteOrderMark) }
            UTF16       { $Encoder = New-Object -TypeName Text.UnicodeEncoding -ArgumentList ($false, $ByteOrderMark) }
            UTF16BE     { $Encoder = New-Object -TypeName Text.UnicodeEncoding -ArgumentList ($true, $ByteOrderMark) }
            UTF32       { $Encoder = New-Object -TypeName Text.UTF32Encoding -ArgumentList ($false, $ByteOrderMark) }
            UTF32BE     { $Encoder = New-Object -TypeName Text.UTF32Encoding -ArgumentList ($true, $ByteOrderMark) }
        }
    }

    Process {
        $Item = Get-Item -Path $File
        $Content = Get-Content -Path $Item

        Write-Verbose -Message ('Converting: {0}' -f $Item.FullName)
        [IO.File]::WriteAllLines($Item.FullName, $Content, $Encoder)
    }
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

# Beautify XML strings
# Via: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2016/12/31/how-to-pretty-print-xml-in-powershell-and-text-pipelines/
Function Format-Xml {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [String[]]$Xml
    )

    Begin {
        $Data = New-Object -TypeName Collections.ArrayList
    }

    Process {
        $null = $Data.Add($Xml -join [Environment]::NewLine)
    }

    End {
        $XmlDoc = New-Object -TypeName Xml.XmlDataDocument
        $XmlDoc.LoadXml($Data)

        $StringWriter = New-Object -TypeName IO.StringWriter
        $XmlTextWriter = New-Object -TypeName Xml.XmlTextWriter($StringWriter)
        $XmlTextWriter.Formatting = [Xml.Formatting]::Indented

        $XmlDoc.WriteContentTo($XmlTextWriter)
        $StringWriter.ToString()
    }
}

# Reload selected PowerShell profiles
Function Reload-Profile {
    [CmdletBinding()]
    Param(
        [Switch]$AllUsersAllHosts,
        [Switch]$AllUsersCurrentHost,
        [Switch]$CurrentUserAllHosts,
        [Switch]$CurrentUserCurrentHost=$true
    )

    $ProfileTypes = @('AllUsersAllHosts', 'AllUsersCurrentHost', 'CurrentUserAllHosts', 'CurrentUserCurrentHost')
    foreach ($ProfileType in $ProfileTypes) {
        if (Get-Variable -Name $ProfileType -ValueOnly) {
            if (Test-Path -Path $profile.$ProfileType -PathType Leaf) {
                Write-Verbose -Message ('Sourcing {0} from: {1}' -f $ProfileType, $profile.$ProfileType)
                . $profile.$ProfileType
            } else {
                Write-Warning -Message ("Skipping {0} as it doesn't exist: {1}" -f $ProfileType, $profile.$ProfileType)
            }
        }
    }
}

# Confirm a PowerShell command is available
Function Test-CommandAvailable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name
    )

    foreach ($Command in $Name) {
        Write-Verbose -Message ('Checking command is available: {0}' -f $Command)
        if (!(Get-Command -Name $Command -ErrorAction Ignore)) {
            throw ('Required command not available: {0}' -f $Command)
        }
    }
}

# Confirm a PowerShell module is available
Function Test-ModuleAvailable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name
    )

    foreach ($Module in $Name) {
        Write-Verbose -Message ('Checking module is available: {0}' -f $Module)
        if (!(Get-Module -Name $Module -ListAvailable)) {
            throw ('Required module not available: {0}' -f $Module)
        }
    }
}
