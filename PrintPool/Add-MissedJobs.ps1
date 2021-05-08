param(
    $sqlServer,
    $userName,
    $password
)

function isWithin([int]$days, [datetime]$date){
    [datetime]::Now.AddDays($days).Date -le $date.Date
}

function notToday([datetime]$date){
    [datetime]::Now.Date -ne $date.Date
}

$jobs = Get-PrintJob -ComputerName 3DPrinterPool "XYZPrinting Pool"
$missedjobs = ($jobs | where {(isWithin -3 $_.SubmittedTime)} | Select DocumentName,UserName,SubmittedTime | Sort-Object SubmittedTime)
$missedjobsNottoday = $missedjobs | where {notToday $_.SubmittedTime}

foreach($item in $missedjobsNottoday)
{
    #Assign Job details to Variables    
    $JobName = $item.DocumentName
    $SubmitterAlias = $item.UserName
    $SubmittedDate = $item.SubmittedTime.ToString()
        
    $retries = 0
    $submitsuccess = $false

    #Try to submit job details to SQL and retry up to 5 times if fails
    While(!$submitsuccess){
        try{
            #Add New Job Entry to SQL Database
            invoke-sqlcmd -serverinstance $sqlServer -database 3DPrintDB -username $userName -password $password -query "insert PLAJobs (JobName,SubmitterAlias,SubmittedDate) values('$JobName','$SubmitterAlias','$SubmittedDate')"
            $submitsuccess = $true
        }
        catch{
            if($retries -ge 5){
                $exceptionDetails = $_.Exception
                throw $exceptionDetails
            }
            else{
                Start-Sleep 10
                $retries++
            }
        }
    }
}