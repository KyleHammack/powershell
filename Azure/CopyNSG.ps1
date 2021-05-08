param(
    $nsgOrigin,
    $rgOrigin,
    $nsgDestination,
    $rgDestination
)

$nsg = Get-AzureRmNetworkSecurityGroup -Name $nsgOrigin -ResourceGroupName $rgOrigin
$nsgRules = Get-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg
$newNsg = Get-AzureRmNetworkSecurityGroup -name $nsgDestination -ResourceGroupName $rgDestination
foreach ($nsgRule in $nsgRules) {
    Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $newNsg `
        -Name $nsgRule.Name `
        -Protocol $nsgRule.Protocol `
        -SourcePortRange $nsgRule.SourcePortRange `
        -DestinationPortRange $nsgRule.DestinationPortRange `
        -SourceAddressPrefix $nsgRule.SourceAddressPrefix `
        -DestinationAddressPrefix $nsgRule.DestinationAddressPrefix `
        -Priority $nsgRule.Priority `
        -Direction $nsgRule.Direction `
        -Access $nsgRule.Access
}
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $newNsg