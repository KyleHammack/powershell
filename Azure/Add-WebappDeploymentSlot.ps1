Param(
[Parameter(Mandatory = $true)]
[string]$webAppName,
[Parameter(Mandatory = $true)]
[string]$resourceGroupName,
[Parameter(Mandatory = $true)]
[string]$slotName
)

$srcapp = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $webAppName
New-AzWebAppSlot -ResourceGroupName $resourceGroupName -Name $webAppName -AppServicePlan $webAppName.serverfarmid -Slot $slotName -SourceWebApp $srcapp