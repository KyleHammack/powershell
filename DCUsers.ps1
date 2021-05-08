# Note : This script uses the TS Module created by ShayLevy (http://archive.msdn.microsoft.com/PSTerminalServices) 
 

cls 
Import-Module PSTerminalServices -ErrorAction SilentlyContinue
$computer = Get-Content "C:\localbin\PS_Scripts\RDPDC\Servers.txt"
ForEach ($comp in $computer) {
$rtn = Test-Connection -ComputerName $comp -Count 1 -Quiet
        IF($rtn -eq 'True') {
                 Try{
				 	write-host "Checking $comp" -foregroundcolor Yellow
                    Get-TSSession -ComputerName $comp -filter {$_.username -ne '' -and $_.connectionstate -eq 'disconnected'} | stop-tssession -force
                }
                catch {
                    Write-host "Failed to Scan : $comp" -ForegroundColor Red
                }
                }
        else {
            Write-host "Request Time Out on : $comp " -ForegroundColor Red
        }
    }
Write-Host "Script Completed" -ForegroundColor Green