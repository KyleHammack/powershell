workflow Restart-ComputerParallel {

 param ([string[]]$computernames)

 foreach -parallel ($computer in $computernames) {
   inlinescript {Write-Host "Rebooting $using:computer"}
   Restart-Computer -PSComputerName $computer -Force -Wait -For WMI
   inlinescript {Write-Host "$using:computer is up"}
 }

}