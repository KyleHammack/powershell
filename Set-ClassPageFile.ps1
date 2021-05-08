function Set-ClassPageFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,Position = 0)]
        [string]$computerName
    )
    try {
        $System = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges -ComputerName $computerName
        
        if($System.AutomaticManagedPageFile) {
            $System.AutomaticManagedPageFile = $false
            $System.Put()
        }
        $PageFile = Get-WmiObject Win32_PageFileSetting -ComputerName $computerName
        $IL = $PageFile.Name
        if($PageFile.InitialSize -eq 0) {$IS = 'SystemManaged'} else {$IS = $PageFile.InitialSize}
        $PageFile.Delete()
        Set-WmiInstance -Class Win32_PageFileSetting -ComputerName $computerName `
                        -Arguments @{Name='C:\pagefile.sys';`
                                     InitialSize = 20480;`
                                     MaximumSize = 20480}
        $PFS = [PSCustomObject] @{
                    'OrigLocation' = $IL;`
                    'OrigInitialSize' = $IS;`
                    'NewLocation' = "C:\pagefile.sys";`
                    'NewSize' = 20480;
        }
        return $PFS
    }
    catch {
        Write-host $_.Exception.Message
        $line = $_.InvocationInfo.ScriptLineNumber
        Write-host "Error was in Line $line"
    }
}
