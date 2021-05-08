<#######Before running script, run the below commented commands on each SQL node as local admin to: Install SQL CU8, Install Failover Clustering, and set SQL permissions. 
############You must also domain join SQL Servers before proceeding:

Invoke-WebRequest 'https://download.microsoft.com/download/6/e/7/6e72dddf-dfa4-4889-bc3d-e5d3a0fd11ce/SQLServer2019-KB4577194-x64.exe' -OutFile 'C:\SQL2019-CU8.exe'
. 'C:\SQL2019-CU8.exe' /quiet /IAcceptSQLServerLicenseTerms /IAcceptROpenLicenseTerms /Action=Patch /AllInstances

Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools

Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force
Set-PsRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module SqlServer -AllowClobber

Invoke-Sqlcmd -Query @"
USE master; 
CREATE LOGIN [BUILTIN\ADMINISTRATORS] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
ALTER SERVER ROLE [sysadmin] ADD MEMBER [BUILTIN\ADMINISTRATORS];
GO

GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM]
GO
GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM]
GO
GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM]
GO 

sp_configure 'contained database authentication', 1;
RECONFIGURE WITH OVERRIDE;
GO

sp_configure 'backup compression default', 1;
RECONFIGURE WITH OVERRIDE;
GO
"@

###After the above you can run this script on SQL01
#######>

# Need to set
$clustername = "sqlclu"
$ClusterNode1 = "kyletestsql01"
$ClusterNode2 = "kyletestsql02"
$ClusterNode3 = "kyletestsql03" # Set $null if only 2 nodes
$WitnessStor = ""
$WitnessStorKey = ""
$DomainUser = ""
$DomainUserPWD = ""
$AGIPPrim = '172.23.5.6' # Create a NIC in Azure to reserve this IP
$AGSubnetPrim = '255.255.255.0'
$AGIPSec = '172.24.5.5' # Create a NIC in Azure to reserve this IP # Set $null if single subnet cluster
$AGSubnetSec = '255.255.255.0' # Set $null if single subnet cluster

# Can leave as is or change
$AGName = $clustername+'AG'
$SqlAgDB = 'AlwaysOnAGInitialSetup'
$AGListener = $AGName+'lsnr'
$DNN = $AGName+'DNN'
$DNNPort = '7777'

# Dont touch
$domain = $env:userDNSDOMAIN
$agPath = "SQLSERVER:\SQL\$ClusterNode1\DEFAULT\AvailabilityGroups\$AGName"
$serverArray = if($ClusterNode3){@($ClusterNode1,$ClusterNode2,$ClusterNode3)}else{@($ClusterNode1,$ClusterNode2)}

$ErrorActionPreference = "Stop"

###################################################### LogonUser
############################################################################################################
function ImpersonateAs([PSCredential] $cred)
{
    [IntPtr] $userToken = [Security.Principal.WindowsIdentity]::GetCurrent().Token
    $userToken
    $ImpersonateLib = $script:ImpersonateLib = Add-Type -PassThru -Namespace 'Lib.Impersonation' -Name ImpersonationLib -MemberDefinition @'
[DllImport("advapi32.dll", SetLastError = true)]
public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, ref IntPtr phToken);

[DllImport("kernel32.dll")]
public static extern Boolean CloseHandle(IntPtr hObject);
'@

    $bLogin = $ImpersonateLib::LogonUser($cred.GetNetworkCredential().UserName, $cred.GetNetworkCredential().Domain, $cred.GetNetworkCredential().Password, 
    9, 0, [ref]$userToken)

    if ($bLogin)
    {
        $Identity = New-Object Security.Principal.WindowsIdentity $userToken
        $context = $Identity.Impersonate()
    }
    else
    {
        throw "Can't log on as user '$($cred.GetNetworkCredential().UserName)'."
    }
    $context, $userToken
}

$ComputerSystem = Get-WmiObject Win32_ComputerSystem
$cred = New-Object System.Management.Automation.PSCredential("$DomainUser@$($ComputerSystem.Domain)", $(ConvertTo-SecureString -String $DomainUserPWD  -AsPlainText -Force))

($oldToken, $context, $newToken) = ImpersonateAs -cred $cred


###################################################### Set SQL Services Auto-Delayed Start
############################################################################################################
try {
        $session = New-PSSession -ComputerName $serverArray -Credential $cred
        Invoke-Command -Session $session -ScriptBlock {
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SQLSERVERAGENT' -Name 'Start' -Value 2
            New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SQLSERVERAGENT' -Name 'DelayedAutostart' -Value 1 -PropertyType 'DWord'
            New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\MSSQLSERVER' -Name 'DelayedAutostart' -Value 1 -PropertyType 'DWord'
        }
}
catch {

    Write-Output "Failed to modify SQL Services:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}


###################################################### Create FC
############################################################################################################
try {
        $cluster = New-Cluster -Name $clustername -Node $serverArray -NoStorage -Force -ErrorAction Stop
        (Get-Cluster).SameSubnetThreshold = 20
        sleep 30
        Set-ClusterQuorum -CloudWitness -AccountName $WitnessStor -AccessKey $WitnessStorKey -Endpoint 'core.windows.net'
}
catch {

    Write-Output "Failed to create Cluster:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}

###################################################### Enable AO
############################################################################################################

try {
    Invoke-Command -Session $session -ScriptBlock {
        Import-Module "SqlServer" -DisableNameChecking

        Enable-SqlAlwaysOn -ServerInstance . -Force -Confirm:$false
        Enable-SqlAlwaysOn -Path "SQLSERVER:\Sql\$($env:computername)\Default" -Force -Confirm:$false

        $endpoint = New-SqlHadrEndpoint AlwaysONMirroringEndpoint -Port 5022 -Path "SQLSERVER:\SQL\$($env:computername)\Default"
        Set-SqlHadrEndpoint -InputObject $endpoint -State "Started" | Out-Null

        Get-Service -Name MSSQLSERVER | Restart-Service
        Get-Service -Name SQLSERVERAGENT | Start-Service
    }
}
catch {

    Write-Output "Failed to enable AlwaysOn:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}

#Grant computer accounts connect to mirroring endpoint
try{
    foreach($node in $serverArray){
        $serverArray | Where-Object { $_ -ne $node } | ForEach-Object {
$SQLPermissionQry = @"
USE [master];
CREATE LOGIN `"$("$env:USERDOMAIN\$($_)$")`" FROM WINDOWS WITH DEFAULT_DATABASE=[master];
GRANT CONNECT ON ENDPOINT::[AlwaysONMirroringEndpoint] TO [$("$env:USERDOMAIN\$($_)$")];
"@
Invoke-Sqlcmd -Query $SQLPermissionQry -ServerInstance $node
        }
    }
}
catch {

    Write-Output "Failed to add Computer account permissions to mirroring endpoint:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}


#Create Test DB
try{
    $srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$ClusterNode1")
    $db = New-Object Microsoft.SqlServer.Management.Smo.Database($srv, $SqlAgDB)
    $db.Create()
}
catch {

    Write-Output "Failed to create test database:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}

# backup the database on the primary replica/server (full database backup)
try{
    $DbBackup = New-Object Microsoft.SqlServer.Management.Smo.Backup
    $DbBackup.Database = $SqlAgDB
    $DbBackup.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database
    $DbBackup.Initialize = $true
    $DbBackup.Incremental = $false
    $DbBackup.Devices.AddDevice("$($SqlAgDB)_full.bak",[Microsoft.SqlServer.Management.Smo.DeviceType]::File)
    $DbBackup.SqlBackup($srv)
}
catch {

    Write-Output "Failed to backup test database:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}


#Setup AG
try{
    $replicas = @()
    foreach($node in $serverArray){
        if($node -eq $ClusterNode1){
            $replicas += New-SqlAvailabilityReplica -Name "$node" -EndpointUrl "TCP://$node.$($domain):5022" `
                            -FailoverMode "Automatic" -AvailabilityMode "SynchronousCommit" -SeedingMode "Automatic" -BackupPriority 50 `
                            -ConnectionModeInSecondaryRole AllowAllConnections -ReadonlyRoutingConnectionUrl TCP://$node.$($domain):1433 `
                            -Version ((Get-Item SQLSERVER:\SQL\$node\DEFAULT).Version) -AsTemplate
        }
        elseif($AGIPSec -and ($node -eq $ClusterNode3)){
            $replicas += New-SqlAvailabilityReplica -Name "$node" -EndpointUrl "TCP://$node.$($domain):5022" `
                            -FailoverMode "Manual" -AvailabilityMode "AsynchronousCommit" -SeedingMode "Automatic" -BackupPriority 0 `
                            -ConnectionModeInSecondaryRole AllowAllConnections -ReadonlyRoutingConnectionUrl TCP://$node.$($domain):1433 `
                            -Version ((Get-Item SQLSERVER:\SQL\$node\DEFAULT).Version) -AsTemplate
        }
        else{
            $replicas += New-SqlAvailabilityReplica -Name "$node" -EndpointUrl "TCP://$node.$($domain):5022" `
                            -FailoverMode "Automatic" -AvailabilityMode "SynchronousCommit" -SeedingMode "Automatic" -BackupPriority 1 `
                            -ConnectionModeInSecondaryRole AllowAllConnections -ReadonlyRoutingConnectionUrl TCP://$node.$($domain):1433 `
                            -Version ((Get-Item SQLSERVER:\SQL\$node\DEFAULT).Version) -AsTemplate
        }
    }
    New-SqlAvailabilityGroup -Name $AGName -Path "SQLSERVER:\SQL\$ClusterNode1\DEFAULT" -AvailabilityReplica $replicas -Database @("$SqlAgDB")
}
catch {

    Write-Output "Failed to create Availability Group:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}

try{
    $serverArray | Where-Object {$_ -ne $ClusterNode1} | ForEach-Object {

    Join-SqlAvailabilityGroup -path "SQLSERVER:\SQL\$_\DEFAULT" -Name $AGName

$SQLPermissionQry = @"
USE [master];
ALTER AVAILABILITY GROUP [$AGName] 
    GRANT CREATE ANY DATABASE
 GO
"@
    Invoke-Sqlcmd -Query $SQLPermissionQry -ServerInstance $_
    }
}
catch {

    Write-Output "Failed to join replicas to Availability Group:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}

try{
    if($AGIPSec){
        New-SqlAvailabilityGroupListener -Name $AGListener -StaticIp @("$AGIPPrim/$AGSubnetPrim","$AGIPSec/$AGSubnetSec") -Path $agPath
    }
    else{
        New-SqlAvailabilityGroupListener -Name $AGListener -StaticIp "$AGIPPrim/$AGSubnetPrim" -Path $agPath
    }
}
catch {

    Write-Output "Failed to create Listener:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}

# Add Distributed Network Name
try{
    Add-ClusterResource -Name $DNNPort -ResourceType 'Distributed Network Name' -Group $AGName
    Get-ClusterResource -Name $DNNPort | Set-ClusterParameter -Name DnsName -Value $DNN
    $dependency = '[' + $AGName + '_' + $AGListener + '] or [' + $DNNPort + ']'
    Set-ClusterResourceDependency -Resource $AGName -Dependency $dependency
    Start-ClusterResource -Name $DNNPort
}
catch {

    Write-Output "Failed to add Distributed Network Name:"
    Write-Output "    Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "    Exception Message: $($_.Exception.Message)"
    Write-Output "    Exception HResult: $($_.Exception.HResult)"
    Exit $($_.Exception.HResult)
}

# Clean up Powershell Sessions
Remove-PSSession -Session $session



<# connection sample!!??
$sqlc = New-Object system.data.sqlclient.sqlconnection
$sqlc.connectionstring = "Data source=$DNN;User ID=$DomainUser;Password=$DomainUserPWD;MultiSubnetFailover=True;Integrated Security=SSPI;"
$sqlcmd = New-Object system.data.sqlclient.sqlcommand
$sqlcmd.CommandTimeout = 60
$sqlcmd.Connection = $sqlc
$sqladap = New-Object system.data.sqlclient.sqldataadapter

$sqlcmd.commandtext=@"
use master
SELECT name FROM master.dbo.sysdatabases
select @@SERVERNAME
"@


$sqladap.SelectCommand=$sqlcmd
$ds = New-Object system.data.dataset
$sqladap.Fill($ds) | Out-Null
$ds.Tables[0]
"Node: $(($ds.Tables[1]).Column1)"


$sqlcmd.commandtext=@"
use MirrorTestSetup
INSERT INTO t 
VALUES ($($i));
SELECT TOP (1000) [a]
  FROM [MirrorTestSetup].[dbo].[t]
"@
$sqladap.SelectCommand=$sqlcmd
$ds = New-Object system.data.dataset
$sqladap.Fill($ds) | Out-Null
"Node: $(($ds.Tables[0]).a)"



### to failover
Switch-SqlAvailabilityGroup -Path $agPath
Switch-SqlAvailabilityGroup -Path $agPath2
Switch-SqlAvailabilityGroup -Path $agPath3 -AllowDataLoss -Force

#to set DBs to resume after "-allowDataloss -force" you need to
#ALTER DATABASE [AlwaysOnAGInitialSetup] SET HADR RESUME;
#>

<#




#NOTES 
#either use Multisubnet (MultiSubnetFailover=True)in connection string or modify how AGL registers DNS:

Get-ClusterResource 'GEC-SQLAOCLAG_GEC-SQLAOCLAG' | Get-ClusterParameter
GEC-SQLAOCLAG_GEC-SQLAOCLAG RegisterAllProvidersIP 1                                UInt32   
set it to 0 for only active IPs to be registered
The second parameter is called HostRecordTTL. This parameter governs how long (in seconds) before cached DNS entries on a client OS are expired, forcing the client OS to re-query the DNS server again to obtain the current IP address. By default, this value is 1200 (20 minutes). 


    >Get-ClusterResource <AG Listener Resource Name> | Set-ClusterParameter -Name HostRecordTTL -Value 120
    >Get-ClusterResource <AG Listener Resource Name> | Set-ClusterParameter -Name RegisterAllProvidersIP -Value 0

Get-ClusterResource 'GEC-SQLAOCLAG_GEC-SQLAOCLAG' | Set-ClusterParameter -Name HostRecordTTL -Value 60


    To force updating DNS on Windows Server 2012 or 2012 R2: 

    >Get-ClusterResource <AG Listener Resource Name> | Update-ClusterNetworkNameResource

    To force updating DNS on Windows Server 2008 or 2008R2: 

    >Cluster.exe RES <AG Listener Resource Name> /registerdns

MultiSubnetFailover=True



#########SCOM cluster up help

USE master; 
CREATE LOGIN [BUILTIN\ADMINISTRATORS] FROM WINDOWS WITH DEFAULT_DATABASE=[master]; 
ALTER SERVER ROLE [sysadmin] ADD MEMBER [BUILTIN\ADMINISTRATORS]; 
GO

sp_configure 'contained database authentication', 1; 
RECONFIGURE WITH OVERRIDE; 
GO

sp_configure 'backup compression default', 1; 
RECONFIGURE WITH OVERRIDE; 
GO



#>
