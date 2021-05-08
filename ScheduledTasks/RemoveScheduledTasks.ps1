param(
    $taskname,
    $filepath,
    $serverlistpath
)

$servers = get-content $serverlistpath

Invoke-Command -ComputerName $servers -ScriptBlock {
    Unregister-ScheduledTask -TaskName $taskname -Confirm:$false
    if($filepath -not $null){
        Remove-Item -Path $filepath
    }
}
