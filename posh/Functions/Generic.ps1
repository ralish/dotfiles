Write-Verbose -Message (Get-DotFilesMessage -Message 'Importing generic functions ...')

# Load our custom formatting data
$null = $FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Generic.format.ps1xml'))

#region Encoding

# Convert a hex string to a byte array
# Via: https://www.reddit.com/r/PowerShell/comments/5rhjsy/hex_to_byte_array_and_back/
Function Convert-HexToBytes {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Hex
    )

    Process {
        $Bytes = [Byte[]]::new($Hex.Length / 2)

        for ($i = 0; $i -lt $Hex.Length; $i += 2) {
            $Bytes[$i / 2] = [Convert]::ToByte($Hex.Substring($i, 2), 16)
        }

        $Bytes
    }
}

# Convert a byte array to a hex string
# Via: https://www.reddit.com/r/PowerShell/comments/5rhjsy/hex_to_byte_array_and_back/
Function Convert-BytesToHex {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Byte[]]$Bytes
    )

    Process {
        $Hex = [Text.StringBuilder]::new($Bytes.Length * 2)

        foreach ($Byte in $Bytes) {
            $null = $Hex.AppendFormat('{0:x2}', $Byte)
        }

        $Hex.ToString()
    }
}

# Convert a string from Base64 form
Function ConvertFrom-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    Process {
        [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($String))
    }
}

# Convert a string from URL encoded form
Function ConvertFrom-URLEncoded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    Process {
        [Net.WebUtility]::UrlDecode($String)
    }
}

# Convert a string to Base64 form
Function ConvertTo-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    Process {
        [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
    }
}

# Convert a text file to the given encoding
Function ConvertTo-TextEncoding {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [String[]]$Path,

        [ValidateSet('ASCII', 'UTF-7', 'UTF-8', 'UTF-16', 'UTF-16BE', 'UTF-32', 'UTF-32BE')]
        [String]$Encoding = 'UTF-8',
        [Switch]$ByteOrderMark,

        [ValidateSet('ASCII', 'UTF-7', 'UTF-8', 'UTF-16', 'UTF-16BE', 'UTF-32', 'UTF-32BE')]
        [String]$SourceEncoding,
        [Switch]$SourceByteOrderMark
    )

    Begin {
        $EncodingClasses = @{
            'ASCII'    = 'Text.ASCIIEncoding'
            'UTF-7'    = 'Text.UTF7Encoding'
            'UTF-8'    = 'Text.UTF8Encoding'
            'UTF-16'   = 'Text.UnicodeEncoding'
            'UTF-16BE' = 'Text.UnicodeEncoding'
            'UTF-32'   = 'Text.UTF32Encoding'
            'UTF-32BE' = 'Text.UTF32Encoding'
        }

        $EncoderParams = @()
        if ($Encoding -match '^UTF-[13]') {
            if ($Encoding -match 'BE$') {
                $EncoderParams += $true
            } else {
                $EncoderParams += $false
            }
        }
        if ($Encoding -match '^UTF-') {
            $EncoderParams += $ByteOrderMark
        }

        $Encoder = New-Object -TypeName $EncodingClasses[$Encoding] -ArgumentList $EncoderParams

        if ($SourceEncoding) {
            $SourceEncoderParams = @()
            if ($SourceEncoding -match '^UTF-[13]') {
                if ($SourceEncoding -match 'BE$') {
                    $SourceEncoderParams += $true
                } else {
                    $SourceEncoderParams += $false
                }
            }
            if ($SourceEncoding -match '^UTF-') {
                $SourceEncoderParams += $ByteOrderMark
            }

            $SourceEncoder = New-Object -TypeName $EncodingClasses[$SourceEncoding] -ArgumentList $SourceEncoderParams
        }
    }

    Process {
        foreach ($TextFile in $Path) {
            try {
                $Item = Get-Item -LiteralPath $TextFile -ErrorAction Stop
                if ($SourceEncoder) {
                    $Content = [IO.File]::ReadAllLines($Item.FullName, $SourceEncoder)
                } else {
                    $Content = [IO.File]::ReadAllLines($Item.FullName)
                }
            } catch {
                Write-Error -Message $_
                continue
            }

            Write-Verbose -Message ('Converting: {0}' -f $Item.FullName)
            [IO.File]::WriteAllLines($Item.FullName, $Content, $Encoder)
        }
    }
}

# Convert a string to URL encoded form
Function ConvertTo-URLEncoded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    Process {
        [Uri]::EscapeDataString($String)
    }
}

# Determine the encoding of a text file
Function Get-TextEncoding {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [String[]]$Path
    )

    Begin {
        $Results = [Collections.ArrayList]::new()

        # Non-printable characters used to determine if file is binary
        $InvalidChars = [Char[]]@(0..8 + 10..31 + 127 + 129 + 141 + 143 + 144 + 157)

        # Construct an array of identifiable encodings by their preamble
        $Encodings = [Collections.ArrayList]::new()
        foreach ($Encoding in [Text.Encoding]::GetEncodings()) {
            $Preamble = $Encoding.GetEncoding().GetPreamble()
            if ($Preamble) {
                $Encoding | Add-Member -MemberType NoteProperty -Name Preamble -Value $Preamble
                $Encoding | Add-Member -MemberType NoteProperty -Name ByteOrderMark -Value $true
                $null = $Encodings.Add($Encoding)
            }
        }

        # Special case for UTF-16LE encoded XML without BOM (this is legal!)
        $Encoding = [PSCustomObject]@{
            Name          = 'utf-16'
            DisplayName   = 'Unicode via XML declaration'
            CodePage      = '1200'
            Preamble      = [Byte[]]@(60, 0, 63, 0)
            ByteOrderMark = $false
        }
        $null = $Encodings.Add($Encoding)

        # Special case for UTF-16BE encoded XML without BOM (this is legal!)
        $Encoding = [PSCustomObject]@{
            Name          = 'utf-16BE'
            DisplayName   = 'Unicode (Big-Endian) via XML declaration'
            CodePage      = '1201'
            Preamble      = [Byte[]]@(0, 60, 0, 63)
            ByteOrderMark = $false
        }
        $null = $Encodings.Add($Encoding)

        # Sort the array by size of each preamble
        foreach ($Encoding in $Encodings) {
            $Encoding | Add-Member -MemberType ScriptProperty -Name PreambleSize -Value { $this.Preamble.Count }
        }
        $Encodings = $Encodings | Sort-Object -Property PreambleSize -Descending

        # PowerShell Core uses a different parameter to return a byte stream
        $GetContentBytesParam = @{ }
        if ($PSVersionTable.PSEdition -eq 'Core') {
            $GetContentBytesParam['AsByteStream'] = $true
        } else {
            $GetContentBytesParam['Encoding'] = 'Byte'
        }
    }

    Process {
        foreach ($TextFile in $Path) {
            try {
                $Item = Get-Item -LiteralPath $TextFile -ErrorAction Stop
                $Content = Get-Content -LiteralPath $Item.FullName -TotalCount 5 -ErrorAction Stop
            } catch {
                Write-Error -Message $_
                continue
            }

            Write-Verbose -Message ('Processing: {0}' -f $Item.FullName)
            $Result = [PSCustomObject]@{
                File          = $Item
                Encoding      = 'ascii / utf-8'
                ByteOrderMark = $false
            }

            $FoundEncoding = $false
            foreach ($Encoding in $Encodings) {
                [Byte[]]$Bytes = Get-Content -LiteralPath $Item.FullName @GetContentBytesParam -ReadCount $Encoding.Preamble.Count | Select-Object -First 1

                if ($Bytes.Count -ne $Encoding.Preamble.Count) {
                    continue
                }

                if ($Bytes.Count -eq 0) {
                    $Result.Encoding = 'empty'
                    $FoundEncoding = $true
                    break
                }

                if ((Compare-Object -ReferenceObject $Encoding.Preamble -DifferenceObject $Bytes -SyncWindow 0).Length -eq 0) {
                    $Result.Encoding = $Encoding.Name
                    $Result.ByteOrderMark = $Encoding.ByteOrderMark
                    $FoundEncoding = $true
                    break
                }
            }

            if (!$FoundEncoding) {
                if ($Content | Where-Object { $_.IndexOfAny($InvalidChars) -ge 0 }) {
                    $Result.Encoding = 'binary'
                }
            }

            $null = $Results.Add($Result)
        }
    }

    End {
        return $Results
    }
}

#endregion

#region Filesystem

# Summarize a directory by number of dirs/files and total size
Function Get-DirectorySummary {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$Path
    )

    Process {
        if (!$Path) {
            $Path = Get-Location -PSProvider FileSystem
        }

        $Directory = Get-Item -LiteralPath $Path -ErrorAction Ignore
        if ($Directory -isnot [IO.DirectoryInfo]) {
            throw 'Provided path is invalid.'
        }

        $TotalDirs = 0
        $TotalFiles = 0
        $TotalItems = 0
        $TotalSize = 0

        $Items = Get-ChildItem -LiteralPath $Directory -Recurse
        foreach ($Item in $Items) {
            $TotalItems++
            switch ($Item.PSTypeNames[0]) {
                'System.IO.FileInfo' { $TotalFiles++; $TotalSize += $Item.Length }
                'System.IO.DirectoryInfo' { $TotalDirs++ }
            }
        }

        $Summary = [PSCustomObject]@{
            Path  = $Directory
            Dirs  = $TotalDirs
            Files = $TotalFiles
            Items = $TotalItems
            Size  = $TotalSize
        }

        $Summary.PSObject.TypeNames.Insert(0, 'DotFiles.Generic.DirectorySummary')
        return $Summary
    }
}

#endregion

#region Formatting

# Format a number representing the size of some digital information
Function Format-SizeDigital {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateRange("NonNegative")]
        [Double]$Size,

        [ValidateSet(2, 10)]
        [Byte]$Base = 2,

        [ValidateRange(0, 10)]
        [Byte]$Precision = 2
    )

    Process {
        if ($Size -eq 0) {
            return '0 bytes'
        }

        if ($Base -eq 2) {
            $LogBase = 1024
            $LogMagnitudes = 'bytes', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'
        } else {
            $LogBase = 1000
            $LogMagnitudes = 'bytes', 'kB', 'MB', 'GB', 'TB', 'PB'
        }

        $Log = [Math]::Truncate([Math]::Log($Size, $LogBase))
        if ($Log -eq 0) {
            $Result = '{0} bytes' -f $Size
        } else {
            if ($Log -ge $LogMagnitudes.Count) {
                $Log = $LogMagnitudes.Count - 1
            }

            $SizeConverted = $Size / [Math]::Pow($LogBase, $Log)
            $SizeRounded = [Math]::Round($SizeConverted, $Precision)
            $SizeString = $SizeRounded.ToString('N{0}' -f $Precision)
            $Result = '{0} {1}' -f $SizeString, $LogMagnitudes[$Log]
        }

        return $Result
    }
}

# Beautify XML strings
# Via: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2016/12/31/how-to-pretty-print-xml-in-powershell-and-text-pipelines/
Function Format-Xml {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String[]]$Xml
    )

    Begin {
        $Data = [Collections.ArrayList]::new()
    }

    Process {
        $null = $Data.Add($Xml -join [Environment]::NewLine)
    }

    End {
        $XmlDoc = New-Object -TypeName Xml.XmlDataDocument
        $XmlDoc.LoadXml($Data)

        $StringWriter = New-Object -TypeName IO.StringWriter
        $XmlTextWriter = New-Object -TypeName Xml.XmlTextWriter -ArgumentList $StringWriter
        $XmlTextWriter.Formatting = [Xml.Formatting]::Indented

        $XmlDoc.WriteContentTo($XmlTextWriter)
        $StringWriter.ToString()
    }
}

#endregion

#region Path management

# Add an element to a Path type string
Function Add-PathStringElement {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$Element,

        [ValidateSet('Append', 'Prepend')]
        [String]$Action = 'Append',

        [Char]$PathSeparator = [IO.Path]::PathSeparator,
        [Char]$DirectorySeparator = [IO.Path]::DirectorySeparatorChar,

        [Switch]$NoRepair,
        [Switch]$SimpleAlgo
    )

    Begin {
        if (!$SimpleAlgo) {
            if ($Element.EndsWith($DirectorySeparator)) {
                $Element = $Element.TrimEnd($DirectorySeparator)
            }
            $Element += $DirectorySeparator
        }

        $RegExElement = [Regex]::Escape($Element)

        if (!$SimpleAlgo) {
            $RegExElement += '*'
        }

        $SingleElement = '^{0}$' -f $RegExElement
    }

    Process {
        if (!$NoRepair) {
            $Path = Repair-PathString -String $Path -PathSeparator $PathSeparator
        }

        if ($Path -notmatch $SingleElement) {
            $RegExPathSeparator = [Regex]::Escape($PathSeparator)
            $FirstElement = '^{0}{1}' -f $RegExElement, $RegExPathSeparator
            $LastElement = '{0}{1}$' -f $RegExPathSeparator, $RegExElement
            $MiddleElement = '{0}{1}{2}' -f $RegExPathSeparator, $RegExElement, $RegExPathSeparator

            $Path = $Path -replace $FirstElement -replace $LastElement -replace $MiddleElement, $PathSeparator

            if (!$SimpleAlgo) {
                $Element = $PSBoundParameters.Item('Element')
            }

            switch ($Action) {
                'Append' {
                    if ($Path.EndsWith($PathSeparator)) {
                        $Path = '{0}{1}' -f $Path, $Element
                    } else {
                        $Path = '{0}{1}{2}' -f $Path, $PathSeparator, $Element
                    }
                }

                'Prepend' {
                    if ($Path.StartsWith($PathSeparator)) {
                        $Path = '{0}{1}' -f $Element, $Path
                    } else {
                        $Path = '{0}{1}{2}' -f $Element, $PathSeparator, $Path
                    }
                }
            }
        }

        return $Path
    }
}

# Remove an element from a Path type string
Function Remove-PathStringElement {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$Element,

        [Char]$PathSeparator = [IO.Path]::PathSeparator,
        [Char]$DirectorySeparator = [IO.Path]::DirectorySeparatorChar,

        [Switch]$NoRepair,
        [Switch]$SimpleAlgo
    )

    Begin {
        if (!$SimpleAlgo) {
            if ($Element.EndsWith($DirectorySeparator)) {
                $Element = $Element.TrimEnd($DirectorySeparator)
            }
            $Element += $DirectorySeparator
        }

        $RegExElement = [Regex]::Escape($Element)

        if (!$SimpleAlgo) {
            $RegExElement += '*'
        }

        $SingleElement = '^{0}$' -f $RegExElement
    }

    Process {
        if (!$NoRepair) {
            $Path = Repair-PathString -String $Path -PathSeparator $PathSeparator
        }

        if ($Path -match $SingleElement) {
            return [String]::Empty
        }

        $RegExPathSeparator = [Regex]::Escape($PathSeparator)
        $FirstElement = '^{0}{1}' -f $RegExElement, $RegExPathSeparator
        $LastElement = '{0}{1}$' -f $RegExPathSeparator, $RegExElement
        $MiddleElement = '{0}{1}{2}' -f $RegExPathSeparator, $RegExElement, $RegExPathSeparator

        return $Path -replace $FirstElement -replace $LastElement -replace $MiddleElement, $PathSeparator
    }
}

# Remove excess separators from a Path type string
Function Repair-PathString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String,

        [Char]$PathSeparator = [IO.Path]::PathSeparator
    )

    Begin {
        $RegExPathSeparator = [Regex]::Escape($PathSeparator)
    }

    Process {
        $String -replace "^$RegExPathSeparator+" -replace "$RegExPathSeparator+$" -replace "$RegExPathSeparator{2,}", $PathSeparator
    }
}

#endregion
