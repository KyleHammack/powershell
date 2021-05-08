param (
	[string]$rgName,
	[string]$vmName
)

$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
Set-AzureRmVMSqlServerExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.name -Name "SQLIaasExtension" -Version "1.2" -Location $vm.Location