Write-Verbose -Message '[dotfiles] Importing generic functions ...'

# Load our custom formatting data
$FormatDataPaths += Join-Path -Path $PSScriptRoot -ChildPath 'Generic.format.ps1xml'

#region Encoding

# Convert a string from Base64 form
Function ConvertFrom-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($String))
}

# Convert a string from URL encoded form
Function ConvertFrom-URLEncoded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    [Net.WebUtility]::UrlDecode($String)
}

# Convert a string to Base64 form
Function ConvertTo-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}

# Convert a text file to the given encoding
Function ConvertTo-TextEncoding {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseConsistentWhitespace', '')] # PSScriptAnalyzer bug
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
            UTF8        { $Encoder = New-Object -TypeName Text.UTF8Encoding -ArgumentList $ByteOrderMark }
            UTF16       { $Encoder = New-Object -TypeName Text.UnicodeEncoding -ArgumentList @($false, $ByteOrderMark) }
            UTF16BE     { $Encoder = New-Object -TypeName Text.UnicodeEncoding -ArgumentList @($true, $ByteOrderMark) }
            UTF32       { $Encoder = New-Object -TypeName Text.UTF32Encoding -ArgumentList @($false, $ByteOrderMark) }
            UTF32BE     { $Encoder = New-Object -TypeName Text.UTF32Encoding -ArgumentList @($true, $ByteOrderMark) }
        }
    }

    Process {
        foreach ($TextFile in $File) {
            $Item = Get-Item -Path $TextFile
            $Content = Get-Content -Path $Item

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

    [Uri]::EscapeDataString($String)
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

    if (!$Path) {
        $Path = Get-Location -PSProvider FileSystem
    }

    $Directory = Get-Item -Path $Path -ErrorAction Ignore
    if ($Directory -isnot [IO.DirectoryInfo]) {
        throw 'Provided path is invalid.'
    }

    $TotalDirs = 0
    $TotalFiles = 0
    $TotalItems = 0
    $TotalSize = 0

    $Items = Get-ChildItem -Path $Directory -Recurse
    foreach ($Item in $Items) {
        $TotalItems++
        switch ($Item.PSTypeNames[0]) {
            'System.IO.FileInfo' { $TotalFiles++; $TotalSize += $Item.Length }
            'System.IO.DirectoryInfo' { $TotalDirs++ }
        }
    }

    $Summary = [PSCustomObject]@{
        Path = $Directory
        Dirs = $TotalDirs
        Files = $TotalFiles
        Items = $TotalItems
        Size = $TotalSize
    }

    $Summary.PSObject.TypeNames.Insert(0, 'DotFiles.Generic.DirectorySummary')
    return $Summary
}

#endregion

#region Formatting

# Format a number representing the size of some digital information
Function Format-SizeDigital {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Double]$Size,

        [ValidateSet(2, 10)]
        [Byte]$Base=2,

        [ValidateRange(0, 10)]
        [Byte]$Precision=2
    )

    if ($Base -eq 2) {
        $LogBase = 1024
        $LogMagnitudes = @('bytes', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB')
    } else {
        $LogBase = 1000
        $LogMagnitudes = @('bytes', 'kB', 'MB', 'GB', 'TB', 'PB')
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

# Beautify XML strings
# Via: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2016/12/31/how-to-pretty-print-xml-in-powershell-and-text-pipelines/
Function Format-Xml {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String[]]$Xml
    )

    Begin {
        [Collections.ArrayList]$Data = @()
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
        [String]$Action='Append',

        [Char]$PathSeparator=[IO.Path]::PathSeparator,
        [Char]$DirectorySeparator=[IO.Path]::DirectorySeparatorChar,

        [Switch]$NoRepair,
        [Switch]$SimpleAlgo
    )

    if (!$NoRepair) {
        $Path = Repair-PathString -String $Path -PathSeparator $PathSeparator
    }

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
    if ($Path -notmatch $SingleElement) {
        $RegExPathSeparator = [Regex]::Escape($PathSeparator)
        $FirstElement       = '^{0}{1}' -f $RegExElement, $RegExPathSeparator
        $LastElement        = '{0}{1}$' -f $RegExPathSeparator, $RegExElement
        $MiddleElement      = '{0}{1}{2}' -f $RegExPathSeparator, $RegExElement, $RegExPathSeparator

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

# Remove an element from a Path type string
Function Remove-PathStringElement {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$Element,

        [Char]$PathSeparator=[IO.Path]::PathSeparator,
        [Char]$DirectorySeparator=[IO.Path]::DirectorySeparatorChar,

        [Switch]$NoRepair,
        [Switch]$SimpleAlgo
    )

    if (!$NoRepair) {
        $Path = Repair-PathString -String $Path -PathSeparator $PathSeparator
    }

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
    if ($Path -match $SingleElement) {
        return [String]::Empty
    }

    $RegExPathSeparator = [Regex]::Escape($PathSeparator)
    $FirstElement       = '^{0}{1}' -f $RegExElement, $RegExPathSeparator
    $LastElement        = '{0}{1}$' -f $RegExPathSeparator, $RegExElement
    $MiddleElement      = '{0}{1}{2}' -f $RegExPathSeparator, $RegExElement, $RegExPathSeparator

    return $Path -replace $FirstElement -replace $LastElement -replace $MiddleElement, $PathSeparator
}

# Remove excess separators from a Path type string
Function Repair-PathString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String,

        [Char]$PathSeparator=[IO.Path]::PathSeparator
    )

    $RegExPathSeparator = [Regex]::Escape($PathSeparator)
    $String -replace "^$RegExPathSeparator+" -replace "$RegExPathSeparator+$" -replace "$RegExPathSeparator{2,}", $PathSeparator
}

#endregion
