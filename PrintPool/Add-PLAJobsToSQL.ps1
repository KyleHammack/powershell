param(
    $sqlServer,
    $userName,
    $password
)

#Get Today's Date
function isToday ([datetime]$date)
{[datetime]::Now.Date -eq $date.Date}

#Get Today's Print Jobs
$jobs = get-printjob -computername 3DPrinterPool "XYZPrinting Pool"
$todaysjobs = ($jobs | where {(isToday $_.SubmittedTime)} | select DocumentName,UserName,SubmittedTime | Sort-Object SubmittedTime)

If($todaysjobs)
{
    foreach($item in $todaysjobs)
    {
        #Assign Job details to Variables    
        $JobName = $item.DocumentName
        $SubmitterAlias = $item.UserName
        $SubmittedDate = $item.SubmittedTime.ToString()

        #Add New Job Entry to SQL Database
        invoke-sqlcmd -serverinstance $sqlServer -database 3DPrintDB -username $userName -password $password -query "insert PLAJobs (JobName,SubmitterAlias,SubmittedDate) values('$JobName','$SubmitterAlias','$SubmittedDate')"
    }
}
