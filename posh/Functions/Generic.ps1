Start-DotFilesSection -Type 'Functions' -Name 'Generic'

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Generic.format.ps1xml'))

#region Encoding

# Convert a byte array to a hex string
# Via: https://www.reddit.com/r/PowerShell/comments/5rhjsy/hex_to_byte_array_and_back/
Function Convert-BytesToHex {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Byte[]]$Bytes
    )

    Process {
        $Hex = [Text.StringBuilder]::new($Bytes.Count * 2)

        foreach ($Byte in $Bytes) {
            $null = $Hex.AppendFormat('{0:x2}', $Byte)
        }

        $Hex.ToString()
    }
}

# Convert a hex string to a byte array
# Via: https://www.reddit.com/r/PowerShell/comments/5rhjsy/hex_to_byte_array_and_back/
Function Convert-HexToBytes {
    [CmdletBinding()]
    [OutputType([Byte[]])]
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

# Convert a string from Base64 form
Function ConvertFrom-Base64 {
    [CmdletBinding()]
    [OutputType([String])]
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
    [OutputType([String])]
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
    [OutputType([String])]
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
    [OutputType([Void])]
    Param(
        [Parameter(ValueFromPipeline)]
        [String[]]$Path,

        [ValidateSet('ASCII', 'UTF-7', 'UTF-8', 'UTF-16', 'UTF-16BE', 'UTF-32', 'UTF-32BE')]
        [String]$Encoding = 'UTF-8',
        [Switch]$ByteOrderMark,

        [ValidateSet('ASCII', 'UTF-7', 'UTF-8', 'UTF-16', 'UTF-16BE', 'UTF-32', 'UTF-32BE')]
        [String]$SourceEncoding,
        [Switch]$SourceByteOrderMark,

        [Switch]$NoEndOfFileNewline,
        [Switch]$ReplaceLeadingTabs,
        [Switch]$TrimTrailingWhitespace
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
                $SourceEncoderParams += $SourceByteOrderMark
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

            if ($ReplaceLeadingTabs -or $TrimTrailingWhitespace) {
                $Original = $Content
                $Content = [Collections.Generic.List[String]]::new()

                for ($Idx = 0; $Idx -lt $Original.Count; $Idx++) {
                    $Line = $Original[$Idx]

                    if ($ReplaceLeadingTabs) {
                        # Line has leading whitespace & subsequent content
                        if ($Line -match '^(\s+)(.+)') {
                            $Whitespace = $Matches[1]
                            $Remainder = $Matches[2]

                            # Leading whitespace has at least one tab character
                            if ($Whitespace -match '\t') {
                                $Line = '{0}{1}' -f ($Whitespace -replace '\t', '    '), $Remainder
                            }
                        }
                    }

                    if ($TrimTrailingWhitespace) {
                        $Line = $Line.TrimEnd()
                    }

                    $Content.Add($Line)
                }
            }

            Write-Verbose -Message ('Converting: {0}' -f $Item.FullName)
            if ($NoEndOfFileNewline) {
                $FileStream = [IO.File]::Open($Item.FullName, [IO.FileMode]::Truncate)
                $StreamWriter = [IO.StreamWriter]::new($FileStream)

                for ($LineNum = 0; $LineNum -lt ($Content.Count - 1); $LineNum++) {
                    $StreamWriter.WriteLine($Content[$LineNum])
                }

                $StreamWriter.Write($Content[$LineNum])
                $StreamWriter.Close()
                $FileStream.Close()
            } else {
                [IO.File]::WriteAllLines($Item.FullName, $Content, $Encoder)
            }
        }
    }
}

# Convert a string to URL encoded form
Function ConvertTo-URLEncoded {
    [CmdletBinding()]
    [OutputType([String])]
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
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(ValueFromPipeline)]
        [String[]]$Path
    )

    Begin {
        $Results = [Collections.Generic.List[PSCustomObject]]::new()

        # Non-printable characters used to determine if file is binary
        $InvalidChars = [Char[]]@(0..8 + 10..31 + 127 + 129 + 141 + 143 + 144 + 157)

        # Construct an array of identifiable encodings by their preamble
        $Encodings = [Collections.Generic.List[PSCustomObject]]::new()
        foreach ($Encoding in [Text.Encoding]::GetEncodings()) {
            $Preamble = $Encoding.GetEncoding().GetPreamble()
            if ($Preamble) {
                $Encoding | Add-Member -MemberType NoteProperty -Name 'Preamble' -Value $Preamble
                $Encoding | Add-Member -MemberType NoteProperty -Name 'ByteOrderMark' -Value $true
                $Encodings.Add($Encoding)
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
        $Encodings.Add($Encoding)

        # Special case for UTF-16BE encoded XML without BOM (this is legal!)
        $Encoding = [PSCustomObject]@{
            Name          = 'utf-16BE'
            DisplayName   = 'Unicode (Big-Endian) via XML declaration'
            CodePage      = '1201'
            Preamble      = [Byte[]]@(0, 60, 0, 63)
            ByteOrderMark = $false
        }
        $Encodings.Add($Encoding)

        # Sort the array by size of each preamble
        foreach ($Encoding in $Encodings) {
            $Encoding | Add-Member -MemberType ScriptProperty -Name 'PreambleSize' -Value { $this.Preamble.Count }
        }
        $Encodings = $Encodings | Sort-Object -Property 'PreambleSize' -Descending

        # PowerShell Core uses a different parameter to return a byte stream
        $GetContentBytesParam = @{}
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
                Encoding      = 'utf-8'
                ByteOrderMark = $false
            }

            $FoundEncoding = $false
            foreach ($Encoding in $Encodings) {
                [Byte[]]$Bytes = Get-Content -LiteralPath $Item.FullName -ReadCount $Encoding.Preamble.Count @GetContentBytesParam | Select-Object -First 1

                if ($Bytes.Count -ne $Encoding.Preamble.Count) {
                    continue
                }

                if ($Bytes.Count -eq 0) {
                    $Result.Encoding = 'empty'
                    $FoundEncoding = $true
                    break
                }

                if ((Compare-Object -ReferenceObject $Encoding.Preamble -DifferenceObject $Bytes -SyncWindow 0).Count -eq 0) {
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

            $Results.Add($Result)
        }
    }

    End {
        return $Results.ToArray()
    }
}

#endregion

#region Filesystem

# Create a file in each empty directory under a path
Function Add-FileToEmptyDirectories {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String[]]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$FileName = '.keepme',

        # Non-recursive (only direct descendents)
        [String[]]$Exclude = '.git'
    )

    if (!$Path) {
        $Path += $PWD.Path
    }

    $CurrentLocation = Get-Location

    foreach ($Item in $Path) {
        if ($CurrentLocation.Provider.Name -ne 'FileSystem' -and ![IO.Path]::IsPathFullyQualified($Item)) {
            Write-Error -Message ('Skipping relative path as current path is not a file system: {0}' -f $Item)
            continue
        }

        try {
            $DirPath = Get-Item -LiteralPath $Item -Force:$Force -ErrorAction Stop
        } catch {
            Write-Error -Message $_.Message
            continue
        }

        if ($DirPath -isnot [IO.DirectoryInfo]) {
            Write-Error -Message ('Provided path is not a directory: {0}' -f $Item)
            continue
        }

        $FilesToCreate = [Collections.Generic.List[String]]::new()
        Get-ChildItem -LiteralPath $DirPath.FullName -Directory -Exclude $Exclude -Force:$Force | ForEach-Object {
            if ((Get-ChildItem -LiteralPath $_.FullName -Force:$Force | Measure-Object).Count -ne 0) {
                Get-ChildItem -LiteralPath $_.FullName -Directory -Recurse -Force:$Force | ForEach-Object {
                    if ((Get-ChildItem -LiteralPath $_.FullName -Force:$Force | Measure-Object).Count -eq 0) {
                        # Subdirectory (not top-level) with no children
                        $FilesToCreate.Add((Join-Path -Path $_.FullName -ChildPath $FileName))
                    }
                }
            } else {
                # Top-level subdirectory (minus exclusions) with no children
                $FilesToCreate.Add((Join-Path -Path $_.FullName -ChildPath $FileName))
            }
        }

        foreach ($FilePath in $FilesToCreate) {
            $null = New-Item -Path $FilePath -ItemType File
        }
    }
}

# Summarize a directory by number of dirs/files and total size
Function Get-DirectorySummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
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
            throw 'Provided path is not a directory: {0}' -f $Path
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

# Add quotes to strings with spaces
Function Add-QuotesToStringWithSpace {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String,

        [ValidateSet('Single', 'Double')]
        [String]$Type = 'Double'
    )

    Begin {
        switch ($Type) {
            'Single' { $Quote = "'" }
            'Double' { $Quote = '"' }
        }
    }

    Process {
        if ($String.Contains(' ')) {
            return '{0}{1}{0}' -f $Quote, $String
        }

        return $String
    }
}

# Format a number representing the size of some digital information
Function Format-SizeDigital {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateRange(0, [Double]::MaxValue)]
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
# Via: https://learn.microsoft.com/en-au/archive/blogs/sergey_babkins_blog/how-to-pretty-print-xml-in-powershell-and-text-pipelines
Function Format-Xml {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [String[]]$Xml,

        [ValidateRange(0, 8)]
        [Int]$IndentSize = 4,

        [Switch]$OmitXmlDeclaration
    )

    Begin {
        $Data = [Collections.Generic.List[String]]::new()
    }

    Process {
        $XmlString = '{0}{1}' -f ($Xml -join [Environment]::NewLine), [Environment]::NewLine
        $Data.Add($XmlString)
    }

    End {
        $StringReader = [IO.StringReader]::new($Data)

        $StringWriter = [IO.StringWriter]::new()
        $XmlWriterSettings = [Xml.XmlWriterSettings]::new()
        if ($IndentSize -gt 0) {
            $XmlWriterSettings.Indent = $true
            $XmlWriterSettings.IndentChars = [String]::new(' ', $IndentSize)
        }
        $XmlWriterSettings.OmitXmlDeclaration = $OmitXmlDeclaration.ToBool()
        $XmlWriter = [Xml.XmlWriter]::Create($StringWriter, $XmlWriterSettings)

        $XmlDoc = [Xml.XmlDocument]::new()
        $XmlDoc.Load($StringReader)
        $XmlDoc.WriteContentTo($XmlWriter)

        # Explicitly dispose to ensure buffer is flushed
        $XmlWriter.Dispose()
        $StringWriter.ToString()
    }
}

# Sort XML elements
# Via: https://danielsmon.com/2017/03/10/diff-xml-via-sorting-xml-elements-and-attributes/
Function Sort-XmlElement {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Xml.XmlElement[]]$XmlElement,

        [Switch]$SortAttributes,

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]$Depth = 0,

        [ValidateRange(0, [Int]::MaxValue)]
        [Int]$MaxDepth = 25
    )

    Begin {
        if ($MaxDepth -lt $Depth) {
            throw 'Maximum sorting depth cannot be less than current depth.'
        }
    }

    Process {
        foreach ($Element in $XmlElement) {
            $Children = @()
            $Attributes = @()

            if ($Element.HasChildNodes) {
                if ($Depth -lt $MaxDepth) {
                    $ChildElements = @($Element.ChildNodes | Where-Object NodeType -EQ 'Element')
                    foreach ($ChildElement in $ChildElements) {
                        Sort-XmlElement -XmlElement $ChildElement -SortAttributes:$SortAttributes -Depth ($Depth + 1) -MaxDepth $MaxDepth
                    }
                }

                $Children = @($Element.ChildNodes | Sort-Object -Property 'OuterXml')
            }

            if ($Element.HasAttributes) {
                if ($SortAttributes) {
                    $Attributes = @($Element.Attributes | Sort-Object -Property 'Name')
                } else {
                    $Attributes = @($Element.Attributes)
                }
            }

            $Element.RemoveAll()

            foreach ($Child in $Children) {
                $null = $Element.AppendChild($Child)
            }

            foreach ($Attribute in $Attributes) {
                $null = $Element.Attributes.Append($Attribute)
            }
        }
    }
}

#endregion

#region Object properties

Function Add-GroupObjectComputerProperty {
    [CmdletBinding()]
    [OutputType([Void], [Microsoft.PowerShell.Commands.GroupInfo[]])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [Microsoft.PowerShell.Commands.GroupInfo[]]$GroupObject,

        [Switch]$Force
    )

    Process {
        foreach ($GroupInfo in $GroupObject) {
            $SkipGroup = $false

            foreach ($GroupItem in $GroupInfo.Group) {
                if ([String]::IsNullOrEmpty($GroupItem.PSComputerName)) {
                    Write-Error -Message 'Group item has no PSComputerName property.'
                    $SkipGroup = $true
                    break
                }
            }

            if ($SkipGroup) {
                continue
            }

            $Computers = ($GroupInfo.Group.PSComputerName | Sort-Object) -join ', '
            $GroupInfo | Add-Member -Name 'Computer' -MemberType NoteProperty -Value $Computers -PassThru -Force:$Force
        }
    }
}

#endregion

#region Path management

# Add an element to a Path type string
Function Add-PathStringElement {
    [CmdletBinding()]
    [OutputType([String])]
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
    [OutputType([String])]
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
    [OutputType([String])]
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

Complete-DotFilesSection
