$null = Start-DotFilesSection -Type 'Functions' -Name 'VMware'

# Optimises VMware virtual machines
Function Global:Optimize-VMwareVirtualMachine {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path
    )

    $BaseDir = Get-Item -LiteralPath $Path -ErrorAction 'Ignore'
    if ($BaseDir -isnot [IO.DirectoryInfo]) {
        $ExcMsg = "Path is not a directory: ${Path}"
        $ErrExc = [ArgumentException]::new($ExcMsg)
        $ErrCat = [Management.Automation.ErrorCategory]::InvalidArgument
        $ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'PSInvalidArgument', $ErrCat, $Path)
        $PSCmdlet.ThrowTerminatingError($ErrRec)
    }

    $WriteProgressParams = @{ Activity = 'Optimizing VMware VMs' }

    Write-Progress @WriteProgressParams -Status 'Enumerating directories' -PercentComplete 1
    $SubDirs = Get-ChildItem -LiteralPath $BaseDir.FullName -Directory -Recurse
    $NoRecurseDirs = [Collections.Generic.List[String]]::new()
    $DirsProcessed = 0

    if (Test-IsWindows) {
        $StringComparisonType = [StringComparison]::OrdinalIgnoreCase
    } else {
        $StringComparisonType = [StringComparison]::Ordinal
    }

    foreach ($SubDir in $SubDirs) {
        $DirsProcessed++
        $DirPathTerminated = $SubDir.FullName + [IO.Path]::DirectorySeparatorChar

        $NoRecurse = $false
        foreach ($NoRecurseDir in $NoRecurseDirs) {
            if ($DirPathTerminated.StartsWith($NoRecurseDir, $StringComparisonType)) {
                Write-Debug -Message "Ignoring directory: ${DirPathTerminated}"
                $NoRecurse = $true
                break
            }
        }

        if ($NoRecurse) { continue }

        # Never recurse into these directories
        $CachesDir = (Join-Path -Path $SubDir.FullName -ChildPath 'caches') + [IO.Path]::DirectorySeparatorChar
        $NoRecurseDirs.Add($CachesDir)

        # Check if directory has a single VM
        $VmxFiles = @(Get-ChildItem -LiteralPath $SubDir.FullName -File | Where-Object Extension -EQ '.vmx')
        if ($VmxFiles.Count -eq 0 -or $VmxFiles.Count -ge 2) {
            if ($VmxFiles.Count -ge 2) {
                $NoRecurseDirs.Add($DirPathTerminated)
                Write-Warning -Message "Skipping directory with multiple VMX files: $($SubDir.FullName)"
            }

            continue
        }

        # Attempt to retrieve the VM name
        $VmxFile = $VmxFiles[0]
        $VmDisplayName = Get-Content -LiteralPath $VmxFile.FullName | Where-Object { $PSItem -match '^displayName = "(.+)"' }
        if ($VmDisplayName) {
            $VmName = $Matches[1]
        } else {
            $VmName = $VmxFile.Name
        }

        Write-Progress @WriteProgressParams -Status "Optimizing VM: ${VmName}" -PercentComplete ($DirsProcessed / $SubDirs.Count * 100)
        Write-Verbose -Message "Optimizing VM: ${VmName}"

        # Check if the VM is locked
        $LckDirs = @(Get-ChildItem -LiteralPath $SubDir.FullName -Directory | Where-Object Name -Match '\.lck$')
        if ($LckDirs.Count -ne 0) {
            $NoRecurseDirs.Add($DirPathTerminated)
            Write-Warning -Message "Skipping locked VM: ${VmName}"
            continue
        }

        # Remove temporary data (handles `-Confirm` / `-WhatIf`)
        Get-ChildItem -LiteralPath $SubDir.FullName -Directory | Where-Object Name -EQ 'caches' | Remove-Item -Recurse
        Get-ChildItem -LiteralPath $SubDir.FullName -File | Where-Object Extension -Match '\.(log|scoreboard)$' | Remove-Item
    }

    Write-Progress @WriteProgressParams -Completed
}

Complete-DotFilesSection
