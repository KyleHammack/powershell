function Remove-PRTGDevice{
 
<#
.SYNOPSIS
    Deletes a Device in PRTG.
 
.DESCRIPTION
    Deletes a Device in PRTG by making calls to the web REST API. It can currently delete a device or group from monitoring.
 
.PARAMETER ObjectID
    ID of the Device or Group to delete. Deleting a Group by ObjectID will delete all devices in the group as well as the group itself. To only delete the contained objects use the Group parameter.

.PARAMETER  ComputerName
    Name of the Device(s) to delete.

.PARAMETER Group
    Name of the Group to delete. This deletes all devices under a group and not the group itself. To delete a Group as well as any contained devices use the ObjectID parameter.

.PARAMETER PRTGServer
    Name or IP Address of the PRTG Server.

.PARAMETER Credential
    Credentials of account with permissions to PRTG Server

.PARAMETER Force
    Forces Object deletion without confirmaton.
 
.EXAMPLE
    PS C:> Remove-PRTGDevice -ComputerName 'TestServer' -PRTGServer MyPRTGServer -Credential domain\Kyle
 
.EXAMPLE
    PS C:> $cred = Get-Credential
    PS C:> Remove-PRTGDevice -ObjectID 1234 -PRTGServer MyPRTGServer -Credential $cred

.EXAMPLE
    PS C:> Remove-PRTGDevice -ComputerName $servers -Force -PRTGServer MyPRTGServer -Credential domain\Kyle

.EXAMPLE
    PS C:> get-content newservers.txt | Remove-PRTGDevice -PRTGServer MyPRTGServer -Credential domain\Kyle

.EXAMPLE
    PS C:> Remove-PRTGDevice -Group Build -PRTGServer MyPRTGServer -Credential domain\Kyle -Force
 
.INPUTS
    System.String,System.Int32,System.Switch
#>
 
    [CmdletBinding(

        SupportsShouldProcess=$true,
        ConfirmImpact="High"

    )]# CmdletBinding end

    param(
 
        # parameter options
        # validation
        # cast
        # name and default value
 
        [Parameter(ParameterSetName="ComputerName", Mandatory=$true, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,
 
        [Parameter(ParameterSetName="ObjectID", Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $ObjectID,

        [Parameter(ParameterSetName="Group", Mandatory=$true)]
        [ValidateSet('Build-Azure','Build-OnPrem','Test','Support','Misc')]
        [System.String]
        $Group,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [System.String]
        $PRTGServer,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [Switch]
        $Force

    )# param end
 
  #--------------------------------------------------#
  # settings
  #--------------------------------------------------#
 
  #--------------------------------------------------#
  # functions
  #--------------------------------------------------#
 
  #--------------------------------------------------#
  # modules
  #--------------------------------------------------#
 
  #--------------------------------------------------#
  # main
  #--------------------------------------------------#


    # This block is used to provide optional one-time pre-processing for the function.
    begin{

        # Null $ID
        $ID = $null

        # Set API variables
        $deleteroot = 'http://$PRTGServer/api/deleteobject.htm?approve=1&id='
        $apicreds = '&username=' + $Credential.UserName + '&password=' + $credential.GetNetworkCredential().password

        # Identify and Preprocess Identifier Type Switches
        if($ObjectID){

            $ID = $ObjectID

        }else{

            # Pre-Pull Device list if using ComputerName to find DeviceID's
            $apigetdevicelist = Invoke-webrequest -method get -uri "http://$PRTGServer/api/table.xml?content=devices&output=csvtable&columns=objid,host,group$apicreds"
            $devicecsv = $apigetdevicelist | ConvertFrom-Csv -Delimiter ','

        }# if($ObjectID) end

    }# begin end
 
    # This block is used to provide record-by-record processing for the function.
    process{

        Write-Verbose 'Beginning Process'

        # Handle ID
        if($ID){

            $deleteuri = $deleteroot + $ID + $apicreds

            if($Force -or $PSCmdlet.ShouldProcess($ID,'Delete PRTG Device')){

                try{

                    # Make API request to pause/unpause group
                    $apidelete = Invoke-webrequest -method post -uri $deleteuri

                }# try end

                catch{
            
                    $exceptionDetails = $_.Exception
                    Write-Host "Error Invoking Create Request"
                    throw $exceptionDetails
 
                }# catch end

                Write-Verbose "API Call Succeeded for ID $ID"

            }# if($Force -or $PSCmdlet.ShouldProcess($ID,'Delete PRTG Device')) end

        } # if($ID) end

        # Handle ComputerName
        elseif($ComputerName){
            
            foreach($Name in $ComputerName){

                write-verbose "Starting on $Name"

                # Null DeviceID
                $deviceid = $null

                # Find DeviceID from Name
                $deviceid = ($devicecsv | where {$_.Host -like $Name}).ID

                Write-Verbose "DeviceID for $Name is $deviceid"
                
                # Return error if DeviceID cant be found
                if(!$deviceid){

                    Write-Error "Cannot find $Name. Verify object exists and is spelt correctly."

                }

                else{

                    $deleteuri = $deleteroot + $deviceid + $apicreds

                    if($Force -or $PSCmdlet.ShouldProcess($Name,'Delete PRTG Device')){

                        try{

                            # Make API request to pause/unpause
                            Write-Verbose "Trying API Call for $Name"
                            $apidelete = Invoke-webrequest -method post -uri $deleteuri

                        }# try end

                        catch{

                            $exceptionDetails = $_.Exception
                            Write-Host "Error Invoking Create Request"
                            throw $exceptionDetails
 
                        }# catch end

                        Write-Verbose "API Call for $Name succeeded"

                    }# if($Force -or $PSCmdlet.ShouldProcess($Name,'Delete PRTG Device')) end

                }# else end

            }# foreach($Name in $ComputerName) end

        }# elseif($ComputerName) end

        elseif($Group){

            #Check Group
            if($Group -eq 'Build-Azure'){
                $RealGroup = 'Build Machines'
            }elseif($Group -eq 'Test'){
                $RealGroup = 'Test Host Machines'
            }elseif($Group -eq 'Support'){
                $RealGroup = 'Support Machines'
            }elseif($Group -eq 'Misc'){
                $RealGroup = 'Misc Machines'
            }elseif($Group -eq 'Build-OnPrem'){
                $RealGroup = 'On-Prem Build Machines'
            }# if($Group -eq 'Build-Azure') end

            # Null DeviceID
            $deviceids = $null

            # Find DeviceID from Name
            $deviceids = ($devicecsv | where {$_.Group -like $RealGroup}).ID

            foreach($deviceid in $deviceids){

                if($Force -or $PSCmdlet.ShouldProcess($Group,'Delete PRTG Group Members')){

                    foreach($ID in $deviceids){

                        Write-Verbose "Starting on $ID"

                        $deleteuri = $deleteroot + $ID + $apicreds

                        try{

                            # Make API request to pause/unpause group
                            $apidelete = Invoke-webrequest -method post -uri $deleteuri

                        }# try end

                        catch{
            
                            $exceptionDetails = $_.Exception
                            Write-Host "Error Invoking Create Request"
                            throw $exceptionDetails
 
                        }# catch end

                        Write-Verbose "API Call Succeeded for ID $ID"

                    }# foreach($ID in $deviceids) end

                }# if($Force -or $PSCmdlet.ShouldProcess($Group,'Delete PRTG Group Members'))

            }# foreach($deviceid in $deviceids) end

        }# elseif($Group) end

    }# process end

    end{

        Write-Verbose 'Finished Processing'

    }# end end

}# function end