<#
.SYNOPSIS
    Moves page file to specified drive and sets to specified size

.DESCRIPTION
     Moves page file to specified drive and sets to specified size

.EXAMPLE
    C:\PS> Move-PageFile -driveLetter "Z" -pageSizeMb 20480
#>

[CmdletBinding()]
param (
    [string]$driveLetter
    [int]$pageSizeMb
)


If (Test-Path $driveLetter:\pagefile.sys)
{
    "Page File Already Set"

}
Else
{  
    # Disables automatically managed page file setting first
    $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
    if ($ComputerSystem.AutomaticManagedPagefile)
    {
       $ComputerSystem.AutomaticManagedPagefile = $false
        $ComputerSystem.Put()
    }

    $CurrentPageFile = Get-WmiObject -Class Win32_PageFileSetting
    #Delete Current Pagefile
    foreach ($cpf in $CurrentPageFile)
    {
        $cpf.Delete()
    }

    $InitialSize = $pageSizeMb
    $MaximumSize = $pageSizeMb
    $Path = "$driveletter:\pagefile.sys"
    # Create new page file on specified drive with defined page file size
    Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name = $Path; InitialSize = $InitialSize; MaximumSize = $MaximumSize}
}
