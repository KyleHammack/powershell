<#
.SYNOPSIS
    Pull machines out of BuildTracker rotation and convert to use managed disks

.DESCRIPTION
     Pull machines out of BuildTracker rotation and convert to use managed disks

.EXAMPLE
    C:\PS> Class-ManagedDisks-v2.ps1
#>

workflow Update-ClassDisks{

param(
    $vms,
    $wfrgname
    $ctxpath
)

    foreach -parallel ($vm in $vms){
        
        InlineScript{
        
            $ctx = Import-AzureRmContext -Path $ctxpath
            $ctx.Context.TokenCache.Deserialize($ctx.Context.TokenCache.CacheData)

            Import-Module ClassValidationTools
            Import-Module BTTools

            # Random sleep so machines dont all start at once
            $rnd = Get-Random -Minimum 1 -Maximum 100

            Start-Sleep -Seconds $rnd

            $session = Connect-Bt
 
            $m = $session.GetMachine($using:vm)

            $status = Get-BtMachineIsRunningLeg -machine $m -session $session

            while($status.IsRunning -eq $true){
                Write-Output $status
                Write-Output 'Sleeping for 5 minutes before rescan'
                Start-Sleep -Seconds 300
                $status = Get-BtMachineIsRunningLeg -machine $m -session $session
            }

            Write-Output "$using:vm is finished running jobs"

       }

       Write-Output "Stopping VM $vm"

       Stop-AzureRmVM -ResourceGroupName $wfrgname -Name $vm -Force

       Write-Output "Converting Disks for VM $vm"

       ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $wfrgname -VMName $vm

       Write-Output "Starting VM $vm"

       Start-AzureRmVM -ResourceGroupName $wfrgname -Name $vm

       InlineScript{
            
           Import-Module ClassValidationTools
           Import-Module BTTools

           Write-Output "Putting $using:vm back in rotation"

           $session = Connect-Bt

           $remResult = Set-ClassMachinesBTRotation -BTMachineList $using:vm -removalReason 'Conversion Complete' -session $session -setRotation ReturnToRotation

           $remResult.Machines
           $remResult.JobRun
           $remResult.LegResult

       }

    }

}

#########

Import-Module ClassValidationTools
Import-Module BTTools

$ctx = Import-AzureRmContext -Path $ctxpath
$ctx.Context.TokenCache.Deserialize($ctx.Context.TokenCache.CacheData)

$session = Connect-Bt

$rgName = 'cls04'

$rgvms = Get-AzureRmVM -ResourceGroupName $rgName

$serviceMach = $rgvms.Name


#region Remove machines from rotation
$machines = foreach($name in $serviceMach){
    $session.GetMachine($name)
}

$curMachGroup = $machines
$curGroupNames = foreach($m in $curMachGroup){$m.Name}

$rotString = $curGroupNames -join ' '
$rotString
$remResult = Set-ClassMachinesBTRotation -BTMachineList $rotString -removalReason 'Removing for Managed Disk conversion' -session $session -setRotation RemoveFromRotation

$remResult.Machines
$remResult.JobRun
$remResult.LegResult
#endregion Remove machines from rotation


#Run Machine Conversion Workflow
Update-ClassDisks -vms $serviceMach -wfrgname $rgname

#Make sure machines are now on Managed Disks
(get-azurermvm -ResourceGroupName cls04).StorageProfile.OsDisk

#Delete old Storage Accounts
Get-AzureRmStorageAccount -ResourceGroupName $rgName | where{$_.StorageAccountName -notmatch 'diag'} | Remove-AzureRmStorageAccount -Force