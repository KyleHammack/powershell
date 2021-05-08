param(
    $sqlServer,
    $userName,
    $password,
    $csvPath
)

$data = import-csv $csvPath
foreach($item in $data)
{
    $JobName = $item.JobName
    $SubmitterAlias = $item.SubmitterAlias
    $SubmittedDate = $item.SubmittedDate
    $DateAddressedbyAdmin = $item.DateAddressedbyAdmin
    $PrintState = $item.PrintState
    $Comments = $item.Comments
    $MailSent = $item.MailSent
    $Retried = $item.Retried
    $RetryState = $item.RetryState

    $stringBuilder = New-Object System.Text.StringBuilder
    $stringBuilder2 = New-Object System.Text.StringBuilder
    $null = $stringBuilder.Append("JobName,SubmitterAlias,SubmittedDate");$stringBuilder2.Append("'$JobName','$SubmitterAlias','$SubmittedDate'")
    $null = IF([string]::IsNullOrWhiteSpace($DateAddressedbyAdmin)){}else{$stringBuilder.Append(",DateAddressedByAdmin");$stringBuilder2.Append(",'$DateAddressedbyAdmin'")}
    $null = IF([string]::IsNullOrWhiteSpace($PrintState)){}else{$stringBuilder.Append(",PrintState");$stringBuilder2.Append(",'$PrintState'")}
    $null = IF([string]::IsNullOrWhiteSpace($MailSent)){}else{$stringBuilder.Append(",MailSent");$stringBuilder2.Append(",'$MailSent'")}
    $null = IF([string]::IsNullOrWhiteSpace($Retried)){}else{$stringBuilder.Append(",Retried");$stringBuilder2.Append(",'$Retried'")}
    $null = IF([string]::IsNullOrWhiteSpace($RetryState)){}else{$stringBuilder.Append(",RetryState");$stringBuilder2.Append(",'$RetryState'")}
    $null = IF([string]::IsNullOrWhiteSpace($Notes)){}else{$stringBuilder.Append(",Comments");$stringBuilder2.Append(",'$Comments'")}
    
    $outputString = $stringBuilder.ToString()
    $outputString2 = $stringBuilder2.ToString()

    invoke-sqlcmd -serverinstance $sqlServer -database 3DPrintDB -username $userName -password $password -query "insert PLAJobs ($outputString) values($outputString2)"
}
