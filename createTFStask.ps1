param(
	$tfsurl
)


$Session = New-PSSession
$PS = Invoke-Command -Session $Session {
$date = Get-Date
$day = $date.day
$month = $date.month
$year = $date.year
$dayvalue = (New-Object system.DateTime($year, $month, 1)).dayofweek.value__
$daycount = 1
$weekcount = 0
$endofmonth = [datetime]::DaysInMonth($year, $month)
$dayofend = (New-Object system.DateTime($year, $month, $endofmonth)).dayofweek
$dayofendnum = [int][dayofweek] "$dayofend"
$endcount = $endofmonth

#Find end of the Second Week for First Iteration Span
while($weekcount -lt 2) {
	If($dayvalue -eq 6){
		$dayvalue = 0
		$daycount++
	}
	while($dayvalue -lt 6) {
		$dayvalue++
		$daycount++
	}
	$weekcount++
}Write-Verbose ("Last Day of First Iteration is " + ($daycount-1))

#Check if date is part of first iteration. If it is not check for extended iteration. If not check if part of second iteration. If not put in first iteration of next month
If($day -lt $daycount){
	Write-Verbose ("Interation Path is OS\"+(get-date -format yyMM)+"\"+(get-date -format yyMM)+"-1")
	$iterationpath = "OS\"+(get-date -format yyMM)+"\"+(get-date -format yyMM)+"-1"
	} elseIf ($dayofend -like "Friday") {
		Write-Verbose "Interation Path is OS\"+(get-date -format yyMM)+"\"+(get-date -format yyMM)+"-2"
		$iterationpath = "OS\"+(get-date -format yyMM)+"\"+(get-date -format yyMM)+"-2"
	} elseIf($day -ge $daycount -and $day -le ($daycount+13)){
		Write-Verbose "Interation Path is OS\"+(get-date -format yyMM)+"\"+(get-date -format yyMM)+"-2"
		$iterationpath = "OS\"+(get-date -format yyMM)+"\"+(get-date -format yyMM)+"-2"
	} else{
		Write-Verbose "Interation Path is OS\"+((get-date -format yyMM).AddMonths(1))+"\"+((get-date -format yyMM).AddMonths(1))+"-1"
		$iterationpath = "OS\"+((get-date -format yyMM).AddMonths(1))+"\"+((get-date -format yyMM).AddMonths(1))+"-1"
	}


#Create New Task in TFS

#Connect to TFS Server
add-pssnapin microsoft.teamfoundation.powershell
$tfs = get-tfsserver $tfsurl
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.WorkItemTracking.Client") > $null
$ws = $tfs.GetService([type]"Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore")
$proj=$ws.projects["OS"]
$workitem = $proj.workitemtypes["Task"].newworkitem()
#Set Fields to desired values
$workitem.title = ""
$workitem.Description = ""
$workitem.iterationpath = $iterationpath
$workitem.areapath = "OS\IOT-Internet of Things\FDS-Fundamentals and Data Science\SE-Service Engineering\Ops Infrastructure"
$workitem.fields["Product Family"].value = "IOT"
$workitem.fields["Product"].value = "Internal"
$workitem.fields["Task Type"].value = "SE Task"
$workitem.fields["Task Type Detail"].value = ""
$workitem.fields["Assigned To"].value =""
#Create Link to Parent Story
$linkType = $ws.WorkItemLinkTypes[[Microsoft.TeamFoundation.WorkItemTracking.Client.CoreLinkTypeReferenceNames]::Hierarchy]
$link = new-object Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemLink($linkType.ReverseEnd, 1277889)
$workitem.WorkItemLinks.Add($link)
#Save and Close Work Item
$workitem.save()
$workitem.close()
#Get and Output New Work Item ID
$newtaskid = $workitem.id
$newtaskid
}