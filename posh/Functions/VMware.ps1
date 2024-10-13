Start-DotFilesSection -Type 'Functions' -Name 'VMware'

# Optimises VMware virtual machines
Function Optimize-VMwareVirtualMachine {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    Param(
        [Parameter(Mandatory)]
        [String]$Path
    )

    $BaseDir = Get-Item -LiteralPath $Path -ErrorAction Ignore
    if ($BaseDir -isnot [IO.DirectoryInfo]) {
        throw 'Provided path is not a directory: {0}' -f $Path
    }

    $WriteProgressParams = @{
        Activity = 'Optimizing VMware VMs'
    }

    Write-Progress @WriteProgressParams -Status 'Enumerating directories' -PercentComplete 1
    $AllDirs = Get-ChildItem -LiteralPath $BaseDir.FullName -Directory -Recurse
    $DirsProcessed = 0
    $NoRecurseDirs = [Collections.Generic.List[String]]::new()

    foreach ($Dir in $AllDirs) {
        $DirsProcessed++
        $DirPathTerminated = $Dir.FullName + [IO.Path]::DirectorySeparatorChar

        foreach ($NoRecurseDir in $NoRecurseDirs) {
            if ($DirPathTerminated.StartsWith($NoRecurseDir)) {
                Write-Debug -Message ('Ignoring directory: {0}' -f $DirPathTerminated)
                continue
            }
        }

        # Never recurse into these directories
        $NoRecurseDirs.Add((Join-Path -Path $Dir.FullName -ChildPath 'caches'))

        # Check if directory has a single VM
        $VmxFiles = @(Get-ChildItem -LiteralPath $Dir.FullName -File | Where-Object Extension -EQ '.vmx' )
        if ($VmxFiles.Count -eq 0) {
            continue
        } elseif ($VmxFiles.Count -gt 1) {
            $NoRecurseDirs.Add($DirPathTerminated)
            Write-Warning -Message ('Skipping directory with multiple VMX files: {0}' -f $Dir.FullName)
            continue
        }

        # Attempt to retrieve the VM name
        $VmxFile = $VmxFiles[0]
        $VmDisplayName = Get-Content -LiteralPath $VmxFile.FullName | Where-Object { $_ -match '^displayName = "(.+)"' }
        if ($VmDisplayName) {
            $VmName = $Matches[1]
        } else {
            $VmName = $VmxFile.Name
        }

        Write-Progress @WriteProgressParams -Status ('Optimizing VM: {0}' -f $VmName) -PercentComplete ($DirsProcessed / $AllDirs.Count * 100)
        Write-Verbose -Message ('Optimizing VM: {0}' -f $VmName)

        # Check if the VM is locked
        $LckDirs = @(Get-ChildItem -LiteralPath $Dir.FullName -Directory | Where-Object Name -Match '\.lck$')
        if ($LckDirs.Count -ne 0) {
            $NoRecurseDirs.Add($DirPathTerminated)
            Write-Warning -Message ('Skipping locked VM: {0}' -f $VmName)
            continue
        }

        # Remove temporary data
        Get-ChildItem -LiteralPath $Dir.FullName -Directory | Where-Object Name -EQ 'caches' | Remove-Item -Recurse
        Get-ChildItem -LiteralPath $Dir.Fullname -File | Where-Object Extension -Match '\.(log|scoreboard)$' | Remove-Item
    }

    Write-Progress @WriteProgressParams -Completed
}

Complete-DotFilesSection
