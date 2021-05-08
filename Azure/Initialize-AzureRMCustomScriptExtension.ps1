function Initialize-AzureRmCustomScriptExtension
{
  <#
      .SYNOPSIS
      Installs and runs an extenstion on an Azure RM VM
      .DESCRIPTION
      Detailed Description
      .EXAMPLE
      Initialize-AzureRmCustomScriptExtension
      explains how to use the command
      can be multiple lines
      .EXAMPLE
      Initialize-AzureRmCustomScriptExtension
      another example
      can have as many examples as you like
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$false, Position=0)]
    [System.String]
    $storageAccountName = '',
    
    [Parameter(Mandatory=$false, Position=1)]
    [System.String]
    $containerName = '',
    
    [Parameter(Mandatory=$false, Position=2)]
    [System.String]
    $storageKey = '',
    
    [Parameter(Mandatory=$false, Position=3)]
    [System.String]
    $resourceGroup = '',
    
    [Parameter(Mandatory=$false, Position=4)]
    [System.String]
    $location = '',
    
    [Parameter(Mandatory=$false, Position=5)]
    [System.String]
    $extensionName = '',
    
    [Parameter(Mandatory=$false, Position=6)]
    [System.String]
    $extensionVersion = '',
    
    [Parameter(Mandatory=$false, Position=7)]
    [System.String]
    $blobFileToRun = '',
    
    [Parameter(Mandatory=$false, Position=8)]
    [System.String[]]
    $vmNames = ''
  )
  
  foreach ($vmName in $VmNames)
  {
    Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourceGroup -VMName $vmName `
    -Name $extensionName -TypeHandlerVersion $extensionVersion `
    -StorageAccountName $StorageAccountName -ContainerName $ContainerName `
    -StorageAccountKey $StorageKey -Location $Location -FileName $blobFileToRun `
    -Run $blobFileToRun
  }
}

