function Disable-Firewall
{
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

}

function Format-DataDisks
{
    $labels = @("Data","Logs")
    Write-Host "Initializing and formatting raw disks"
 
    $disks = Get-Disk |   Where partitionstyle -eq 'raw' | sort number
 
    ## start at S: 
    $letters = 83..89 | ForEach-Object { ([char]$_) }
    $count = 0
 
    foreach($d in $disks) {
        $driveLetter = $letters[$count].ToString()
        $d | 
        Initialize-Disk -PartitionStyle GPT -PassThru |
        New-Partition -UseMaximumSize -DriveLetter $driveLetter |
        Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $labels[$count] `
            -Confirm:$false -Force 
        $count++
    }

}

Disable-Firewall
Format-DataDisks