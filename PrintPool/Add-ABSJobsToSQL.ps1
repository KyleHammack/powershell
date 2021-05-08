param(
    $sqlServer,
    $userName,
    $password
)

#Get Today's Date
function isToday ([datetime]$date)
{[datetime]::Now.Date -eq $date.Date}

#Get Today's Print Jobs from E
$jobsE = get-printjob -computername 3DPrinterPool2 "XYZPrinting E"
$todaysEjobs = ($jobsE | where {(isToday $_.SubmittedTime)} | select DocumentName,UserName,SubmittedTime)

#Get Today's Print Jobs from F
$jobsF = get-printjob -computername 3DPrinterPool2 "XYZPrinting F"
$todaysFjobs = ($jobsF | where {(isToday $_.SubmittedTime)} | select DocumentName,UserName,SubmittedTime)

#Get Today's Print Jobs from G
$jobsG = get-printjob -computername 3DPrinterPool2 "XYZPrinting G"
$todaysGjobs = ($jobsG | where {(isToday $_.SubmittedTime)} | select DocumentName,UserName,SubmittedTime)

If($todaysEjobs)
{
    $todaysABSjobs += $todaysEjobs
}
If($todaysFjobs)
{
    $todaysABSjobs += $todaysFjobs
}
If($todaysGjobs)
{
    $todaysABSjobs += $todaysGjobs
}

If($todaysABSjobs)
{
    $todaysABSjobs = $todaysABSjobs | Sort-Object SubmittedTime
    foreach($item in $todaysABSjobs)
    {
        #Assign Job details to Variables    
        $JobName = $item.DocumentName
        $SubmitterAlias = $item.UserName
        $SubmittedDate = $item.SubmittedTime.ToString()

        #Add New Job Entry to SQL Database
        invoke-sqlcmd -serverinstance $sqlServer -database 3DPrintDB -username $userName -password $password -query "insert ABSJobs (JobName,SubmitterAlias,SubmittedDate) values('$JobName','$SubmitterAlias','$SubmittedDate')"
    }
}