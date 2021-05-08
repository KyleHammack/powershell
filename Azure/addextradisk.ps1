param (
	[string]$rgName,
	[string]$vmName,
	[string]$location, #East US 2
	[string]$storageType, #PremiumLRS
	[int]$diskSizeGB, #128
	[string]$diskNameSuffix, #-datadisk2
	[int]$lun
)

$dataDiskName = $vmName + $diskNameSuffix

$diskConfig = New-AzureRmDiskConfig -SkuName $storageType -Location $location -CreateOption Empty -DiskSizeGB $diskSizeGB
$dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName

$vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
$vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun $lun

Update-AzureRmVM -VM $vm -ResourceGroupName $rgName