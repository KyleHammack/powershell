$servers = Get-Content .\servers.txt
Invoke-Command -ComputerName $servers -ScriptBlock {(get-date)-([System.Management.ManagementDateTimeconverter]::ToDateTime((Get-WmiObject win32_operatingsystem).lastbootuptime))|select days} |
Out-Gridview