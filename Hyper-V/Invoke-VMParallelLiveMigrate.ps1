Workflow Invoke-VMParallelLiveMigrate

{

 Param (

[parameter(Mandatory=$true)][String[]] $VMList,

[parameter(Mandatory=$true)][String] $SourceHost,

[parameter(Mandatory=$true)][String] $DestHost,

[parameter(Mandatory=$true)][String] $DestPath

)

ForEach -Parallel ($VM in $VMList)

{

Move-VM -ComputerName $SourceHost -Name $VM -DestinationHost $DestHost -DestinationStoragePath $DestPath

}

}


# Using Workflow:

# $VMList = Get-VM -ComputerName SOURCE_HOST | Out-GridView -Title “Select one or more VMs to Live Migrate” -PassThru

# Invoke-ParallelLiveMigrate -VMList $VMList.Name -SourceHost SOURCE_HOST -DestHost DEST_HOST -DestPath DRIVE:\FOLDER