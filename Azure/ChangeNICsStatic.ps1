param(
	$RSGs = @((Get-AzureRmResourceGroup).resourcegroupname)

)

foreach($RSG in $RSGs){
  $NICs = (Get-AzureRmNetworkInterface -ResourceGroupName $RSG | Where-Object {$_.ProvisioningState -eq 'Succeeded'}).Name

  foreach($NIC_name in $NICs){
    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $RSG -Name $NIC_name
    $nic.IpConfigurations[0].PrivateIpAllocationMethod = 'Static'
    Set-AzureRmNetworkInterface -NetworkInterface $nic 
    $IP = $nic.IpConfigurations[0].PrivateIpAddress

    Write-Host "The allocation method is now set to"$nic.IpConfigurations[0].PrivateIpAllocationMethod"for the IP address" $IP"." -NoNewline
  }
}
