$null = Start-DotFilesSection -Type 'Functions' -Name 'Generic'

# Load custom formatting data
$FormatDataPaths.Add((Join-Path -Path $PSScriptRoot -ChildPath 'Generic.format.ps1xml'))

#region Encoding

# Convert a byte array to a hex string
# Via: https://www.reddit.com/r/PowerShell/comments/5rhjsy/hex_to_byte_array_and_back/
Function Global:Convert-BytesToHex {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Byte[]]$Bytes
    )

    Begin {
        $Hex = [Text.StringBuilder]::new()
    }

    Process {
        foreach ($Byte in $Bytes) {
            $null = $Hex.AppendFormat('{0:x2}', $Byte)
        }
    }

    End {
        return $Hex.ToString()
    }
}

# Convert a hex string to a byte array
# Via: https://www.reddit.com/r/PowerShell/comments/5rhjsy/hex_to_byte_array_and_back/
Function Global:Convert-HexToBytes {
    [CmdletBinding()]
    [OutputType([Byte[]])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidatePattern('^([0-9a-fA-F]{2})*$')]
        [String]$Hex
    )

    Process {
        $Bytes = [Byte[]]::new($Hex.Length / 2)

        for ($i = 0; $i -lt $Hex.Length; $i += 2) {
            $Bytes[$i / 2] = [Convert]::ToByte($Hex.Substring($i, 2), 16)
        }

        return $Bytes
    }
}

# Convert a string from Base64 format
Function Global:ConvertFrom-Base64 {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String,

        [ValidateSet('ASCII', 'UTF-7', 'UTF-8', 'UTF-16', 'UTF-16BE', 'UTF-32', 'UTF-32BE')]
        [String]$Encoding = 'UTF-8'
    )

    Begin {
        switch ($Encoding) {
            'ASCII' { $Encoder = [Text.ASCIIEncoding]::new() }
            'UTF-7' { $Encoder = [Text.UTF7Encoding]::new() }

            'UTF-8' {
                # No BOM, throw on invalid encoding
                $Encoder = [Text.UTF8Encoding]::new($false, $true)
            }

            'UTF-16' {
                # Little endian, no BOM, throw on invalid encoding
                $Encoder = [Text.UnicodeEncoding]::new($false, $false, $true)
            }

            'UTF-16BE' {
                # Big endian, no BOM, throw on invalid encoding
                $Encoder = [Text.UnicodeEncoding]::new($true, $false, $true)
            }

            'UTF-32' {
                # Little endian, no BOM, throw on invalid encoding
                $Encoder = [Text.UTF32Encoding]::new($false, $false, $true)
            }

            'UTF-32BE' {
                # Big endian, no BOM, throw on invalid encoding
                $Encoder = [Text.UTF32Encoding]::new($true, $false, $true)
            }
        }
    }

    Process {
        $Encoder.GetString([Convert]::FromBase64String($String))
    }
}

# Convert a string from URL encoded format
Function Global:ConvertFrom-URLEncoded {
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

# Convert a string to Base64 format
Function Global:ConvertTo-Base64 {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String,

        [ValidateSet('ASCII', 'UTF-7', 'UTF-8', 'UTF-16', 'UTF-16BE', 'UTF-32', 'UTF-32BE')]
        [String]$Encoding = 'UTF-8'
    )

    Begin {
        switch ($Encoding) {
            'ASCII' { $Encoder = [Text.ASCIIEncoding]::new() }
            'UTF-7' { $Encoder = [Text.UTF7Encoding]::new() }

            'UTF-8' {
                # No BOM, throw on invalid encoding
                $Encoder = [Text.UTF8Encoding]::new($false, $true)
            }

            'UTF-16' {
                # Little endian, no BOM, throw on invalid encoding
                $Encoder = [Text.UnicodeEncoding]::new($false, $false, $true)
            }

            'UTF-16BE' {
                # Big endian, no BOM, throw on invalid encoding
                $Encoder = [Text.UnicodeEncoding]::new($true, $false, $true)
            }

            'UTF-32' {
                # Little endian, no BOM, throw on invalid encoding
                $Encoder = [Text.UTF32Encoding]::new($false, $false, $true)
            }

            'UTF-32BE' {
                # Big endian, no BOM, throw on invalid encoding
                $Encoder = [Text.UTF32Encoding]::new($true, $false, $true)
            }
        }
    }

    Process {
        [Convert]::ToBase64String($Encoder.GetBytes($String))
    }
}

# Convert a text file to the given encoding
Function Global:ConvertTo-TextEncoding {
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
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

        # UTF-7 has no concept of a BOM
        if ($Encoding -match '^UTF-' -and $Encoding -ne 'UTF-7') {
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

            # UTF-7 has no concept of a BOM
            if ($SourceEncoding -match '^UTF-' -and $SourceEncoding -ne 'UTF-7') {
                $SourceEncoderParams += $SourceByteOrderMark
            }

            $SourceEncoder = New-Object -TypeName $EncodingClasses[$SourceEncoding] -ArgumentList $SourceEncoderParams
        }
    }

    Process {
        foreach ($TextFile in $Path) {
            try {
                $Item = Get-Item -LiteralPath $TextFile -ErrorAction 'Stop'
                if ($SourceEncoding) {
                    $Content = [IO.File]::ReadAllLines($Item.FullName, $SourceEncoder)
                } else {
                    $Content = [IO.File]::ReadAllLines($Item.FullName)
                }
            } catch {
                $PSCmdlet.WriteError($PSItem)
                continue
            }

            if ($ReplaceLeadingTabs -or $TrimTrailingWhitespace) {
                $Original = $Content
                $Content = [Collections.Generic.List[String]]::new()

                for ($i = 0; $i -lt $Original.Count; $i++) {
                    $Line = $Original[$i]

                    if ($ReplaceLeadingTabs) {
                        # Line has leading whitespace and subsequent content
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

            Write-Verbose -Message "Converting: $($Item.FullName)"
            if ($NoEndOfFileNewline) {
                try {
                    $FileStream = $StreamWriter = $null

                    $FileStream = [IO.File]::Open($Item.FullName, [IO.FileMode]::Truncate)
                    $StreamWriter = [IO.StreamWriter]::new($FileStream, $Encoder)

                    if ($Content.Count -ne 0) {
                        for ($LineNum = 0; $LineNum -lt ($Content.Count - 1); $LineNum++) {
                            $StreamWriter.WriteLine($Content[$LineNum])
                        }

                        $StreamWriter.Write($Content[$LineNum])
                    }
                } catch {
                    $PSCmdlet.WriteError($PSItem)
                } finally {
                    if ($StreamWriter) { $StreamWriter.Close() }
                    if ($FileStream) { $FileStream.Close() }
                }
            } else {
                try {
                    [IO.File]::WriteAllLines($Item.FullName, $Content, $Encoder)
                } catch { $PSCmdlet.WriteError($PSItem) }
            }
        }
    }
}

# Convert a string to URL encoded format
Function Global:ConvertTo-URLEncoded {
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
Function Global:Get-TextEncoding {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject[]])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String[]]$Path
    )

    Begin {
        $Results = [Collections.Generic.List[PSCustomObject]]::new()

        # Non-printable characters used to guess if the file is binary
        $InvalidChars = [Char[]]@(0..8 + 10..31 + 127 + 129 + 141 + 143 + 144 + 157)

        # Construct an array of identifiable encodings by their preamble
        $Encodings = [Collections.Generic.List[PSCustomObject]]::new()
        foreach ($Encoding in [Text.Encoding]::GetEncodings()) {
            $Preamble = $Encoding.GetEncoding().GetPreamble()
            if ($Preamble) {
                $Encoding | Add-Member -MemberType 'NoteProperty' -Name 'Preamble' -Value $Preamble
                $Encoding | Add-Member -MemberType 'NoteProperty' -Name 'ByteOrderMark' -Value $true
                $Encodings.Add($Encoding)
            }
        }

        # Special case for UTF-16LE encoded XML without a BOM (this is legal!)
        $Encoding = [PSCustomObject]@{
            Name          = 'utf-16'
            DisplayName   = 'Unicode via XML declaration'
            CodePage      = '1200'
            Preamble      = [Byte[]]@(60, 0, 63, 0)
            ByteOrderMark = $false
        }

        $Encodings.Add($Encoding)

        # Special case for UTF-16BE encoded XML without a BOM (this is legal!)
        $Encoding = [PSCustomObject]@{
            Name          = 'utf-16BE'
            DisplayName   = 'Unicode (Big-Endian) via XML declaration'
            CodePage      = '1201'
            Preamble      = [Byte[]]@(0, 60, 0, 63)
            ByteOrderMark = $false
        }

        $Encodings.Add($Encoding)

        # Sort the array by the size of each preamble
        foreach ($Encoding in $Encodings) {
            $Encoding | Add-Member -MemberType 'ScriptProperty' -Name 'PreambleSize' -Value { $this.Preamble.Count }
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
                $Item = Get-Item -LiteralPath $TextFile -ErrorAction 'Stop'
                $Content = Get-Content -LiteralPath $Item.FullName -TotalCount 5 -ErrorAction 'Stop'
            } catch {
                $PSCmdlet.WriteError($PSItem)
                continue
            }

            Write-Verbose -Message "Processing: $($Item.FullName)"
            $Result = [PSCustomObject]@{
                File          = $Item
                Encoding      = 'utf-8'
                ByteOrderMark = $false
            }

            $FoundEncoding = $false
            foreach ($Encoding in $Encodings) {
                [Byte[]]$Bytes = Get-Content -LiteralPath $Item.FullName -ReadCount $Encoding.Preamble.Count @GetContentBytesParam | Select-Object -First 1
                if ($Bytes.Count -ne $Encoding.Preamble.Count) { continue }

                $ComparePreamble = Compare-Object -ReferenceObject $Encoding.Preamble -DifferenceObject $Bytes -SyncWindow 0
                if ($ComparePreamble.Count -eq 0) {
                    $Result.Encoding = $Encoding.Name
                    $Result.ByteOrderMark = $Encoding.ByteOrderMark
                    $FoundEncoding = $true
                    break
                }
            }

            if (!$FoundEncoding) {
                if ($Content | Where-Object { $PSItem.IndexOfAny($InvalidChars) -ge 0 }) {
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
Function Global:Add-FileToEmptyDirectories {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        [ValidateNotNullOrEmpty()]
        [String[]]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$FileName = '.keepme',

        # Non-recursive (only direct descendents)
        [String[]]$Exclude = '.git',

        [Switch]$Force
    )

    $CurrentLocation = Get-Location

    if (!$Path) {
        $Path += $PWD.Path
    }

    foreach ($DirPath in $Path) {
        if (!(Test-IsPathFullyQualified -Path $DirPath)) {
            if ($CurrentLocation.Provider.Name -ne 'FileSystem') {
                $ExcMsg = "Skipping relative path as current path is not a file system: ${DirPath}"
                $ErrExc = [ArgumentException]::new($ExcMsg, 'Path')
                $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
                $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $DirPath)
                $PSCmdlet.WriteError($ErrRec)
                continue
            }

            $DirPath = Join-Path -Path $CurrentLocation -ChildPath $DirPath
        }

        try {
            $DirItem = Get-Item -LiteralPath $DirPath -Force:$Force -ErrorAction 'Stop'
        } catch {
            $PSCmdlet.WriteError($PSItem)
            continue
        }

        if ($DirItem -isnot [IO.DirectoryInfo]) {
            $ExcMsg = "Path is not a directory: ${DirPath}"
            $ErrExc = [ArgumentException]::new($ExcMsg, 'Path')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $DirPath)
            $PSCmdlet.WriteError($ErrRec)
            continue
        }

        $FilesToCreate = [Collections.Generic.List[String]]::new()
        # Retrieve top-level directories in the path minus any exclusions
        Get-ChildItem -LiteralPath $DirItem.FullName -Directory -Force:$Force | ForEach-Object {
            # Ideally we'd use `-Exclude` in `Get-ChildItem` but it's ignored
            # on Windows PowerShell 5.1 when used alongside `-LiteralPath`.
            foreach ($Filter in $Exclude) {
                if ($PSItem.Name -like $Filter) { return }
            }

            # For each top-level subdirectory check if it has any children
            $TopSubDirItems = Get-ChildItem -LiteralPath $PSItem.FullName -Force:$Force | Measure-Object
            if ($TopSubDirItems.Count -ne 0) {
                # Top-level subdirectory with children. Recursively retrieve
                # all subdirectories under it for potential file creation.
                Get-ChildItem -LiteralPath $PSItem.FullName -Directory -Recurse -Force:$Force | ForEach-Object {
                    # For each subdirectory check if it has any children
                    $SubDirItems = Get-ChildItem -LiteralPath $PSItem.FullName -Force:$Force | Measure-Object
                    if ($SubDirItems.Count -eq 0) {
                        # Subdirectory (not top-level) with no children
                        $FilesToCreate.Add((Join-Path -Path $PSItem.FullName -ChildPath $FileName))
                    }
                }
            } else {
                # Top-level subdirectory with no children
                $FilesToCreate.Add((Join-Path -Path $PSItem.FullName -ChildPath $FileName))
            }
        }

        foreach ($FilePath in $FilesToCreate) {
            # Handles `-Confirm` / `-WhatIf`
            $null = New-Item -Path $FilePath -ItemType 'File'
        }
    }
}

# Retrieve a directory summary containing item counts and total size
Function Global:Get-DirectorySummary {
    [CmdletBinding()]
    [OutputType([Void], [PSCustomObject])]
    Param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$Path
    )

    Process {
        if (!$Path) {
            $Path = Get-Location -PSProvider 'FileSystem'
        }

        $Directory = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
        if ($Directory -isnot [IO.DirectoryInfo]) {
            $ExcMsg = "Path is not a directory: ${Path}"
            $ErrExc = [ArgumentException]::new($ExcMsg, 'Path')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
            $PSCmdlet.WriteError($ErrRec)
            return
        }

        $TotalDirs = 0
        $TotalFiles = 0
        $TotalItems = 0
        $TotalSize = 0

        $Items = Get-ChildItem -LiteralPath $Directory.FullName -Recurse
        foreach ($Item in $Items) {
            $TotalItems++
            switch ($Item.PSTypeNames[0]) {
                'System.IO.FileInfo' { $TotalFiles++; $TotalSize += $Item.Length }
                'System.IO.DirectoryInfo' { $TotalDirs++ }
            }
        }

        $Summary = [PSCustomObject]@{
            Path  = $Directory.FullName
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
Function Global:Add-QuotesToStringWithSpace {
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
Function Global:Format-SizeDigital {
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
        if ($Log -ne 0) {
            if ($Log -ge $LogMagnitudes.Count) {
                $Log = $LogMagnitudes.Count - 1
            }

            $SizeConverted = $Size / [Math]::Pow($LogBase, $Log)
            $SizeRounded = [Math]::Round($SizeConverted, $Precision)
            $SizeString = $SizeRounded.ToString("N${Precision}")
            $Result = "${SizeString} $($LogMagnitudes[$Log])"
        } else {
            $Result = "${Size} bytes"
        }

        return $Result
    }
}

# Beautify XML strings
# Via: https://learn.microsoft.com/en-au/archive/blogs/sergey_babkins_blog/how-to-pretty-print-xml-in-powershell-and-text-pipelines
Function Global:Format-Xml {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [String[]]$Xml,

        [ValidateRange(0, 8)]
        [Byte]$IndentSize = 4,

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
        try {
            $StringReader = $StringWriter = $XmlWriter = $null

            $StringReader = [IO.StringReader]::new($Data -join '')
            $StringWriter = [IO.StringWriter]::new()

            $XmlWriterSettings = [Xml.XmlWriterSettings]::new()
            $XmlWriterSettings.OmitXmlDeclaration = $OmitXmlDeclaration.ToBool()

            if ($IndentSize -ne 0) {
                $XmlWriterSettings.Indent = $true
                $XmlWriterSettings.IndentChars = [String]::new(' ', $IndentSize)
            }

            $XmlWriter = [Xml.XmlWriter]::Create($StringWriter, $XmlWriterSettings)

            $XmlDoc = [Xml.XmlDocument]::new()
            $XmlDoc.Load($StringReader)
            $XmlDoc.WriteContentTo($XmlWriter)

            $XmlWriter.Flush()

            return $StringWriter.ToString()
        } catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        } finally {
            if ($XmlWriter) { $XmlWriter.Dispose() }
            if ($StringWriter) { $StringWriter.Dispose() }
            if ($StringReader) { $StringReader.Dispose() }
        }
    }
}

# Sort XML elements
# Via: https://danielsmon.com/2017/03/10/diff-xml-via-sorting-xml-elements-and-attributes/
Function Global:Sort-XmlElement {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding()]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Xml.XmlElement[]]$XmlElement,

        [Switch]$SortAttributes,

        [ValidateRange(0, [Byte]::MaxValue)]
        [Byte]$Depth = 0,

        [ValidateRange(0, [Byte]::MaxValue)]
        [Byte]$MaxDepth = 25
    )

    Begin {
        if ($MaxDepth -lt $Depth) {
            $ExcMsg = "Maximum sorting depth (${MaxDepth}) cannot be less than current depth (${Depth})."
            $ErrExc = [ArgumentException]::new($ExcMsg, 'MaxDepth')
            $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
            $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, "${MaxDepth} < ${Depth}")
            $PSCmdlet.ThrowTerminatingError($ErrRec)
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

# Add a `Computer` property to group objects
Function Global:Add-GroupObjectComputerProperty {
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
                if ($GroupItem.PSObject.Properties.Name -notcontains 'PSComputerName') {
                    $SkipGroup = $true

                    $ExcMsg = 'Group item has no PSComputerName property.'
                    $ErrExc = [Management.Automation.PropertyNotFoundException]::new($ExcMsg)
                    $ErrCat = [Management.Automation.ErrorCategory]::InvalidData
                    $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSItemMissingProperty', $ErrCat, $GroupItem)
                    $PSCmdlet.WriteError($ErrRec)
                    break
                }
            }

            if ($SkipGroup) { continue }

            $Computers = ($GroupInfo.Group.PSComputerName | Sort-Object) -join ', '
            $GroupInfo | Add-Member -Name 'Computer' -MemberType 'NoteProperty' -Value $Computers -PassThru -Force:$Force
        }
    }
}

#endregion

#region Path management

# Add an element to a `Path` type string
Function Global:Add-PathStringElement {
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
        [Switch]$SimpleAlgorithm
    )

    Begin {
        if (!$SimpleAlgorithm) {
            if ($Element.EndsWith($DirectorySeparator)) {
                $Element = $Element.TrimEnd($DirectorySeparator)
            }

            $Element += $DirectorySeparator
        }

        $RegExElement = [Regex]::Escape($Element)

        if (!$SimpleAlgorithm) {
            $RegExElement += '*'
        }

        $SingleElement = "^${RegExElement}$"
    }

    Process {
        if (!$NoRepair) {
            $Path = Repair-PathString -String $Path -PathSeparator $PathSeparator
        }

        if ($Path -notmatch $SingleElement) {
            $RegExPathSeparator = [Regex]::Escape($PathSeparator)
            $FirstElement = "^${RegExElement}${RegExPathSeparator}"
            $LastElement = "${RegExPathSeparator}${RegExElement}$"
            $MiddleElement = "${RegExPathSeparator}${RegExElement}${RegExPathSeparator}"
            $Path = $Path -replace $FirstElement -replace $LastElement -replace $MiddleElement, $PathSeparator

            switch ($Action) {
                'Append' {
                    if ($Path.EndsWith($PathSeparator)) {
                        $Path = "${Path}${Element}"
                    } else {
                        $Path = "${Path}${PathSeparator}${Element}"
                    }
                }

                'Prepend' {
                    if ($Path.StartsWith($PathSeparator)) {
                        $Path = "${Element}${Path}"
                    } else {
                        $Path = "${Element}${PathSeparator}${Path}"
                    }
                }
            }
        }

        return $Path
    }
}

# Remove an element from a `Path` type string
Function Global:Remove-PathStringElement {
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
        [Switch]$SimpleAlgorithm
    )

    Begin {
        if (!$SimpleAlgorithm) {
            if ($Element.EndsWith($DirectorySeparator)) {
                $Element = $Element.TrimEnd($DirectorySeparator)
            }

            $Element += $DirectorySeparator
        }

        $RegExElement = [Regex]::Escape($Element)

        if (!$SimpleAlgorithm) {
            $RegExElement += '*'
        }

        $SingleElement = "^${RegExElement}$"
    }

    Process {
        if (!$NoRepair) {
            $Path = Repair-PathString -String $Path -PathSeparator $PathSeparator
        }

        if ($Path -match $SingleElement) {
            return ''
        }

        $RegExPathSeparator = [Regex]::Escape($PathSeparator)
        $FirstElement = "^${RegExElement}${RegExPathSeparator}"
        $LastElement = "${RegExPathSeparator}${RegExElement}$"
        $MiddleElement = "${RegExPathSeparator}${RegExElement}${RegExPathSeparator}"

        return $Path -replace $FirstElement -replace $LastElement -replace $MiddleElement, $PathSeparator
    }
}

# Remove excess separators from a `Path` type string
Function Global:Repair-PathString {
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
        return $String -replace "^${RegExPathSeparator}+" -replace "${RegExPathSeparator}+$" -replace "${RegExPathSeparator}{2,}", $PathSeparator
    }
}

#endregion

Complete-DotFilesSection
