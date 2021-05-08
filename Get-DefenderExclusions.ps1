function Get-ClassDefenderExclusions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,Position = 0)]
        [string]$computerName,
        
        #Takes a comma separated string of exclusions to check
        [Parameter(Mandatory,Position = 1)]
        [string]$exclusionCheckString
    )

    #Check and split if multiple exclusions
    $exclusionCheckArray = $exclusionCheckString -split ','
    $exclusionCheckArray = $exclusionCheckArray.trim()

    try {
        #Check if Defender Feature Installed
        $stateScript = {Get-Windowsfeature | Where-Object name -eq Windows-Defender}
        $state = Invoke-Command -ComputerName $computerName -ScriptBlock $stateScript -ErrorAction Stop
        
        #Check Defender Path Exclusions
        if($state.Installed -eq $true) {
            $defenderstatus = Invoke-Command -ComputerName $computerName -ScriptBlock {(Get-Mppreference)} -ErrorAction Stop
            $serverexclusions = $defenderstatus.ExclusionPath
            $exclusionMatch = $true
            $missingexclusions = $null
            $missingexclusions = $exclusionCheckArray | ?{$serverexclusions -notcontains $_}
            if($missingexclusions){
                $defender = [PSCustomObject] @{
                    'DefenderInstalled' = $state.Installed
                    'ExclusionCheckString' = $exclusionCheckString
                    'ExclusionMatch' = $false
                    'MissingExclusions' = $missingexclusions
                }
            }
            else{
                $missingexclusions = @{}
                $defender = [PSCustomObject] @{
                    'DefenderInstalled' = $state.Installed
                    'ExclusionCheckString' = $exclusionCheckString
                    'ExclusionMatch' = $true
                }
            }

            Write-Host ":Get-DedupReport:$computerName"
            $state | Select Name,InstallState | Out-String | Write-Host

            return $defender
        }
        else {
                $defender = [PSCustomObject] @{
                    'DefenderInstalled' = $false
                    'ExclusionString' = $exclusionCheckString
                    'ExclusionMatch' = $false
                }
            Write-Host ":Get-DedupReport:$computerName"
            $state | Select Name,InstallState,Installed | Out-String | Write-Host

            return $defender
        }
    }
    catch {
        Write-host $_.Exception.Message
        $line = $_.InvocationInfo.ScriptLineNumber
        Write-host "Error was in Line $line"
    }
}