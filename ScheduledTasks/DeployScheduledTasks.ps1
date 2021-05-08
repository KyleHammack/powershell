param(
    $filepath,
    $serverlistpath,
    $daysofweek = "Sunday",
    $time = "4am",
    $username,
    $password
)

$filename = ($filepath -split "\")[-1]
$servers = get-content $serverlistpath
foreach($server in $servers){
    Copy-Item -Path $filepath -Destination \\$server\C$\$filename
}
Invoke-Command -ComputerName $servers -ScriptBlock {
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -WorkingDirectory 'C:\' -Argument ".\$filename"
    $trigger =  New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysofweek -At $time
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $filename -RunLevel Highest -User $username -Password $password
}
