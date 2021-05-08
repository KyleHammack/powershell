function Set-PRTGDevice{
 
<#
.SYNOPSIS
    Modifies a Device in PRTG.
 
.DESCRIPTION
    Modifies a Device in PRTG by making calls to the web REST API. It can currently pause or un-pause a device or group from monitoring.
 
.PARAMETER ObjectID
    ID of the Device or Group to modify.

.PARAMETER  ComputerName
    Name of the Device(s) to modify.

.PARAMETER Action
    Indicates the action to take on the specified objects. Valid values are Pause and Unpause.

.PARAMETER PRTGServer
    Name or IP Address of the PRTG Server.

.PARAMETER Credential
    Credentials of account with permissions to PRTG Server
 
.EXAMPLE
    PS C:> Set-PRTGDevice -ComputerName 'TestServer' -Action Pause -PRTGServer MyPRTGServer -Credential domain\Kyle
 
.EXAMPLE
    PS C:> Set-PRTGDevice -ObjectID 1234 -Action Unpause -PRTGServer MyPRTGServer -Credential domain\Kyle

.EXAMPLE
    PS C:> $cred = Get-Credential
    PS C:> Set-PRTGDevice -ComputerName $servers -Action Pause -PRTGServer MyPRTGServer -Credential $cred

.EXAMPLE
    PS C:> get-content newservers.txt | Set-PRTGDevice -Action Pause -PRTGServer MyPRTGServer -Credential domain\Kyle

.EXAMPLE
    PS C:> Set-PRTGDevice -Group Build -Action Unpause -PRTGServer MyPRTGServer -Credential domain\Kyle
 
.INPUTS
    System.String,System.Int32
 
.OUTPUTS
    PSCustomObject
 
#>
 
    [CmdletBinding()]
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
        [ValidateSet('Pause','Unpause')]
        [System.String]
        $Action,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [System.String]
        $PRTGServer,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.CredentialAttribute()]
        $Credential
 
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
        $pauseroot = 'http://$PRTGServer/api/pause.htm?id='
        $apicreds = '&username=' + $Credential.UserName + '&password=' + $credential.GetNetworkCredential().password

        # Check if Pausing or Unpausing
        if($Action -eq 'Unpause'){
            $apiaction = '&action=1'
        }elseif($Action -eq 'Pause'){
            $apiaction = '&action=0'
        }# if($Action -eq 'Pause') end

        # Identify and Preprocess Identifier Type Switches
        if($ObjectID){
            $ID = $ObjectID
        }elseif($Group -eq 'Build-Azure'){
            $ID = 2060
        }elseif($Group -eq 'Test'){
            $ID = 2061
        }elseif($Group -eq 'Support'){
            $ID = 2062
        }elseif($Group -eq 'Misc'){
            $ID = 2063
        }elseif($Group -eq 'Build-OnPrem'){
            $ID = 4808
        }else{
            # Pre-Pull Device list if using ComputerName to find DeviceID's
            $apigetdevicelist = Invoke-webrequest -method get -uri "http://$PRTGServer/api/table.xml?content=devices&output=csvtable&columns=objid,host$apicreds"
            $devicecsv = $apigetdevicelist | ConvertFrom-Csv -Delimiter ','
        }# if($ObjectID) end

    }# begin end
 
    # This block is used to provide record-by-record processing for the function.
    process{

        Write-Verbose 'Beginning Process'

        # Handle ID
        if($ID){

            $pauseuri = $pauseroot + $ID + $apiaction + $apicreds

            try{

                # Make API request to pause/unpause group
                $apipause = Invoke-webrequest -method post -uri $pauseuri

            }# try end

            catch{
            
                $exceptionDetails = $_.Exception
                Write-Host "Error Invoking Create Request"
                throw $exceptionDetails
 
            }# catch end

            Write-Verbose "API Call Succeeded"

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
                    return
                }

                $pauseuri = $pauseroot + $deviceid + $apiaction + $apicreds

                try{

                    # Make API request to pause/unpause
                    Write-Verbose "Trying API Call for $Name"
                    $apipause = Invoke-webrequest -method post -uri $pauseuri

                }# try end

                catch{

                    $exceptionDetails = $_.Exception
                    Write-Host "Error Invoking Create Request"
                    throw $exceptionDetails
 
                }# catch end

                Write-Verbose "API Call for $Name succeeded"

            }# foreach($Name in $ComputerName) end
        }# elseif($ComputerName) end
    }# process end

    end{
        Write-Verbose 'Finished Processing'
    }# end end

}# function end