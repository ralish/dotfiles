# Retrieve a status report on all AGPM controlled GPOs
Function Get-ControlledGpoStatus {
    [CmdletBinding()]
    Param()

    Test-ModuleAvailable -Name Microsoft.Agpm

    $Results = @()
    $AgpmGPOs = Get-ControlledGpo
    $DomainGPOs = Get-GPO -All

    foreach ($AgpmGPO in $AgpmGPOs) {
        $Result = [PSCustomObject]@{
            PSTypeName  = 'DotFiles.GroupPolicy.ControlledGpoStatus'
            Name        = $AgpmGPO.Name
            AGPM        = $AgpmGPO
            Domain      = $null
            Status      = 'Unknown'
        }

        $DomainGPO = $DomainGPOs | Where-Object { $_.DisplayName -eq $AgpmGPO.Name }
        if ($DomainGPO) {
            $Result.Domain = $DomainGPO

            if ([Int32]$AgpmGPO.ComputerVersion -eq $DomainGPO.Computer.DSVersion -and [Int32]$AgpmGPO.UserVersion -eq $DomainGPO.User.DSVersion) {
                $Result.Status = 'Current'
            } elseif ([Int32]$AgpmGPO.ComputerVersion -le $DomainGPO.Computer.DSVersion -and [Int32]$AgpmGPO.UserVersion -le $DomainGPO.User.DSVersion) {
                $Result.Status = 'Out-of-date (Import)'
            } elseif ([Int32]$AgpmGPO.ComputerVersion -ge $DomainGPO.Computer.DSVersion -and [Int32]$AgpmGPO.UserVersion -ge $DomainGPO.User.DSVersion) {
                $Result.Status = 'Newer (Deploy)'
            } else {
                $Result.Status = 'Inconsistent'
            }
        } else {
            $Result.Status = 'Only exists in AGPM'
        }

        $Results += $Result
    }

    $MissingGPOs = $DomainGPOs | Where-Object { $_.DisplayName -notin $AgpmGPOs.Name }
    foreach ($MissingGPO in $MissingGPOs) {
        $Result = [PSCustomObject]@{
            PSTypeName  = 'DotFiles.GroupPolicy.ControlledGpoStatus'
            Name        = $MissingGPO.DisplayName
            AGPM        = $null
            Domain      = $MissingGPO
            Status      = 'Only exists in Domain'
        }

        $Results += $Result
    }

    Update-TypeData -TypeName 'DotFiles.GroupPolicy.ControlledGpoStatus' -DefaultDisplayPropertySet @('Name', 'Status') -Force

    return $Results
}
