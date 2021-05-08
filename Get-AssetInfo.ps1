function Get-AssetInfo{

param([string[]]$ComputerName)

$machinfo = @()
foreach($server in $ComputerName){
    
    $mi = Get-WmiObject -Class Win32_SystemEnclosure -ComputerName $server
    $mi2 = Get-WmiObject -Class Win32_Bios -ComputerName $server
    $at = $mi.SMBIOSAssetTag
    $sn = $mi2.SerialNumber
    $mach = [PSCustomObject] @{
                'DeviceName' = $server
                'AssetTag' = $at
                'SerialNumber' = $sn
    }# mach end

    $machinfo += $mach

}
$machinfo|Out-GridView

}