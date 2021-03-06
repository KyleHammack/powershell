workflow Configure-VMMHostsParallel {

#Parameter requires full name and path to CSV Server List, List should contain server names in first column and desired Management IP in second column with no headers
param(
    [string]$scvmmFqdn
    [string]$clusterFqdn
    [string]$sofsFqdn
    [string]$scAccount
    [Parameter(ParameterSetName='ServerCSV',Mandatory = $True)][String]$serverCSV,
    [Parameter(ParameterSetName='SingleServer',Mandatory = $True)][string]$SingleServerName,
    [Parameter(ParameterSetName='SingleServer',Mandatory = $True)][string]$SingleServerIP
)

Get-SCVMMServer -ComputerName $scvmmFqdn
If(($SingleServerName -ne $null) -and ($SingleServerIP -ne $null)){
    $SingleServer = $SingleServerName + "," + $SingleServerIP
}

If($serverCSV -ne $null){$ServerList = Get-Content $ServerCSV}

$servers = $ServerList + $SingleServer

ForEach -Parallel($server in $servers){
	$serverinfo = $server -split ","
	$servername = $serverinfo[0]
	$serverip = $serverinfo[1]

	Inlinescript{
		#Install Failover-Clustering and Hyper-V If not already installed
			If((Get-WindowsFeature -Name Failover-Clustering).installed -eq $False){add-windowsfeature Failover-Clustering -includeallsubfeature -includemanagementtools}
			If((Get-WindowsFeature -Name Hyper-V).installed -eq $False){add-windowsfeature Hyper-V -includeallsubfeature -includemanagementtools}
		#Disable unused network adapters and rename used adapters for easy reference
			Get-NetAdapter | ? status -eq 'disconnected' | Disable-NetAdapter -Confirm:$false
			$adapters = Get-NetAdapter | ? linkspeed -eq '1 Gbps'
			$adapters[0] | rename-netadapter -newname "1GB 1"
			$adapters[1] | rename-netadapter -newname "1GB 2"
			$adapters = Get-NetAdapter | ? linkspeed -eq '10 Gbps'
			$adapters[0] | rename-netadapter -newname "10GB 1"
			$adapters[1] | rename-netadapter -newname "10GB 2"
		#Create and configure Host Management NIC Team
			New-NetLbfoTeam -Name "Host Management Team" -TeamMembers "1GB 2" -Confirm:$false
			Do{
			Start-Sleep -Seconds 30
			} Until (((get-netlbfoteam -name "Host Management Team").status).ToString() -eq "Up")
			New-NetIPAddress -InterfaceAlias "Host Management Team" -IPAddress $using:serverip -PrefixLength 23 -DefaultGateway "10.179.46.1"
			Set-DnsClientServerAddress -InterfaceAlias "Host Management Team" -ServerAddresses ("157.54.14.146","157.54.14.162","157.59.200.240")
		} -PSComputerName $servername

	#Reboot for Hyper-V
		Restart-Computer -PSComputerName $servername -Force -Wait -For PowerShell

	#Add server to VMM
		$runAsAccount = Get-SCRunAsAccount -Name "$scAccount" -ID "6be68c7d-225a-47e1-812b-6e13bb760493"
		$hostGroup = Get-SCVMHostGroup -ID "f27313a4-7904-4db3-8d43-967e8cf15e3a" -Name "ADV Cluster A"
		Add-SCVMHost -ComputerName $servername -VMHostGroup $hostGroup -Credential $runAsAccount

	#Add SMB Share to VMM Host
		$JobGroupID = [Guid]::NewGuid().ToString()
		$vmHost = Get-SCVMHost -ComputerName $servername
		$smbShare = Get-SCStorageFileShare -ID "2831a0fc-1310-4f45-8cfb-4609b6466261" -Name "VMs"
		Register-SCStorageFileShare -StorageFileShare $smbShare -VMHost $vmHost -JobGroup $JobGroupID
		Set-SCVMHost -VMHost $vmHost -JobGroup $JobGroupID -VMPaths "\\$sofsFqdn\VMs" -BaseDiskPaths "\\$sofsFqdn\VMs"

	#Create and configure Cluster NIC Team in VMM
		$JobGroupID = [Guid]::NewGuid().ToString()
		$oneAdapter0 = Get-SCVMHostNetworkAdapter -VMHost $vmHost | ? ConnectionName -eq "10GB 1"
		$oneAdapter1 = Get-SCVMHostNetworkAdapter -VMHost $vmHost | ? ConnectionName -eq "10GB 2"
		$uplinkPortProfileSet = Get-SCUplinkPortProfileSet -Name "Cluster Team_18556e05-eae2-4237-82e3-aa6098cd7fac" -ID "04c7c18f-8ae3-49f0-9c92-5edb1b2eea9b"
		Set-SCVMHostNetworkAdapter -VMHostNetworkAdapter $oneAdapter0 -UplinkPortProfileSet $uplinkPortProfileSet -JobGroup $JobGroupID
		Set-SCVMHostNetworkAdapter -VMHostNetworkAdapter $oneAdapter1 -UplinkPortProfileSet $uplinkPortProfileSet -JobGroup $JobGroupID
		$networkAdapter = @()
		$networkAdapter += $oneAdapter0
		$networkAdapter += $oneAdapter1
		$logicalSwitch = Get-SCLogicalSwitch -Name "VM Cluster Team" -ID "9b3ef2a3-9760-4d33-8069-f7a1f0a6cfdc"
		New-SCVirtualNetwork -VMHost $vmHost -VMHostNetworkAdapters $networkAdapter -LogicalSwitch $logicalSwitch -JobGroup $JobGroupID

	#Create and Configure Cluster SMB Virtual Switch in VMM
		$vNicLogicalSwitch = Get-SCLogicalSwitch -Name "VM Cluster Team" -ID "9b3ef2a3-9760-4d33-8069-f7a1f0a6cfdc"
		$vmNetwork = Get-SCVMNetwork -Name "VLAN 13 (ADV SMB)" -ID "3050b4e6-f661-47fd-a62b-b953b2d02c66"
		$vmSubnet = Get-SCVMSubnet -VMNetwork $vmNetwork -Name "VLAN 13 (ADV SMB)"
		$vNICPortClassification = Get-SCPortClassification -Name "Live migration  workload" -ID "9d692f2c-8521-4ab5-81ac-17b38156d481"
		$ipV4Pool = Get-SCStaticIPAddressPool -Name "A Cluster SMB Network Pool" -ID "e7734761-26a7-43cf-af7a-9105feab010a"
		New-SCVirtualNetworkAdapter -VMHost $vmHost -Name "SMB" -VMNetwork $vmNetwork -LogicalSwitch $vNicLogicalSwitch  -JobGroup $JobGroupID -VMSubnet $vmSubnet -PortClassification $vNICPortClassification -IPv4AddressType "Static" -IPv4AddressPool $ipV4Pool -MACAddressType "Static" -MACAddress "00:00:00:00:00:00"
		Set-SCVMHost -VMHost $vmHost -JobGroup $JobGroupID

		InlineScript{
			Do{
				Start-Sleep -Seconds 10
				} Until (((get-netadapter -name "vEthernet (SMB)").status) -eq "Up")
			Disable-NetAdapterBinding -Name “vEthernet (SMB)” -ComponentID ms_tcpip6,ms_rspndr,ms_lltdio
			Set-DnsClient -InterfaceAlias “vEthernet (SMB)” -RegisterThisConnectionsAddress:$False
			Add-NetLbfoTeamMember -Name "1GB 1" -Team "Host Management Team" -Confirm:$false
			} -PSComputerName $servername

	#Wait 20 Minutes for DNS to catch up and then make sure server is reachable again before continuing
	Write-Output "Waiting 20 Minutes for DNS Update..."
	Start-Sleep -Seconds 1200
	inlinescript{
		while((Test-Connection -ComputerName $using:servername -Quiet).Equals($False)){
			Write-Output "Waiting for server response..."
			Start-Sleep -Seconds 30
		}
	}
	Write-Output "Connection to Host Re-Established, Adding host to Cluster"

	#Add Host to Cluster
	$hostCluster = Get-SCVMHostCluster -Name $clusterFqdn
	Install-SCVMHostCluster -VMHost $vmHost -VMHostCluster $hostCluster -Credential $runAsAccount -SkipValidation

	#Modify VMM Host Live Migration Settings
	$JobGroupID = [Guid]::NewGuid().ToString()
	$LiveMigrationSubnets = @("192.168.0.0/20","192.168.5.48/28","10.179.46.0/23")
	Set-SCVMHost -VMHost $vmHost -JobGroup $JobGroupID -LiveStorageMigrationMaximum "5" -EnableLiveMigration $true -LiveMigrationMaximum "5" -MigrationPerformanceOption "UseSmbTransport" -MigrationAuthProtocol "CredSSP" -UseAnyMigrationSubnet $false -MigrationSubnet $LiveMigrationSubnets
}
}