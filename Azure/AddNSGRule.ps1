params(
	$RGname,
	$nsgname,
	$source,
	$destination,
	$port,
	$priority,
	$rulename
)


# Get the NSG resource
$nsg = Get-AzureRmNetworkSecurityGroup -Name $nsgname -ResourceGroupName $RGname

# Add the inbound security rule.
$nsg | Add-AzureRmNetworkSecurityRuleConfig -Name $rulename -Access Allow `
    -Protocol Tcp -Direction Inbound -Priority $priority -SourceAddressPrefix $source -SourcePortRange * `
    -DestinationAddressPrefix $destination -DestinationPortRange $port

# Update the NSG.
$nsg | Set-AzureRmNetworkSecurityGroup