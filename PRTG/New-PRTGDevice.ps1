function New-PRTGDevice{
 
<#
.SYNOPSIS
    Creates a new Device in PRTG.
 
.DESCRIPTION
    Creates a new Device in PRTG by making calls to the web REST API. It clones an existing template device (from its device ID) and then un-pauses the newly created device.
 
.PARAMETER  ComputerName
    Name of the new Device(s) to be added to PRTG.
 
.PARAMETER  GroupID
    ID Number of the Device Group the new device should be a member of.

.PARAMETER Group
    Name of the Device Group the new device should be a member of.

.PARAMETER PRTGServer
    Name or IP Address of the PRTG Server.

.PARAMETER Credential
    Credentials of account with permissions to PRTG Server

.EXAMPLE
    PS C:> New-PRTGDevice -ComputerName 'TestServer' -GroupID 2060 -PRTGServer MyPRTGServer -Credential domain\Kyle
 
.EXAMPLE
    PS C:> New-PRTGDevice 'TestServer' 2060 -PRTGServer MyPRTGServer -Credential domain\Kyle

.EXAMPLE
    PS C:> $cred = Get-Credential
    PS C:> New-PRTGDevice 'TestServer' 2060 -PRTGServer MyPRTGServer -Credential $cred

.EXAMPLE
    PS C:> New-PRTGDevice -ComputerName $servers -GroupID 2060 -PRTGServer MyPRTGServer -Credential domain\Kyle

.EXAMPLE
    PS C:> get-content newservers.txt | New-PRTGDevice -GroupID 2060 -PRTGServer MyPRTGServer -Credential domain\Kyle

.EXAMPLE
    PS C:> New-PRTGDevice -ComputerName 'TestServer' -Group Build -PRTGServer MyPRTGServer -Credential domain\Kyle
 
.INPUTS
    System.String,System.Int32,System.Management.Automation.PSCredential
 
.OUTPUTS
    PSCustomObject
 
#>
 
    [CmdletBinding()]
    param(
 
        # parameter options
        # validation
        # cast
        # name and default value
 
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,
 
        [Parameter(Position=1, ParameterSetName = "GroupID", Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $GroupID,

        [Parameter(Position=1, ParameterSetName = "GroupType", Mandatory=$true)]
        [ValidateSet('Build-Azure','Build-OnPrem','Test','Support','Misc')]
        [System.String]
        $Group,

        [Parameter(Position=2, Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [System.String]
        $PRTGServer,

        [Parameter(Position=3, Mandatory=$true)]
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
        # Define results array
        $results = @()

        #Identify GroupID and Group Switches
        if($GroupID){
            $AssignGroup = $GroupID
        }elseif($Group -match 'Build-Azure'){
            $AssignGroup = 2060
        }elseif($Group -match 'Test'){
            $AssignGroup = 2061
        }elseif($Group -match 'Support'){
            $AssignGroup = 2062
        }elseif($Group -match 'Misc'){
            $AssignGroup = 2063
        }elseif($Group -match 'Build-OnPrem'){
            $AssignGroup = 4808
        }
    }
 
    # This block is used to provide record-by-record processing for the function.
    process{

    Write-Verbose 'Beginning Process'

        foreach($Name in $ComputerName){

            write-verbose "Starting on $Name"

            # Build API Device Clone URI
            $copyuri = "http://$PRTGServer/api/duplicateobject.htm?id=4409&name=" + $Name + `
                '&host=' + $Name + `
                '&targetid=' + $AssignGroup + `
                '&username=' + $Credential.UserName + '&password=' + $credential.GetNetworkCredential().password

            try{

                # Make API request to clone template with specified name
                Write-Verbose "Trying Call to create $Name"
                $copyapicall = Invoke-webrequest -method put -uri $copyuri

            }# try end

            catch{
            
                $exceptionDetails = $_.Exception
                Write-Host "Error Invoking Create Request"
                throw $exceptionDetails
 
            }# catch end

            # Build API Device Unpause URI
            $uriresponse = $copyapicall.BaseResponse.ResponseUri.Query
            $newdeviceid = ($uriresponse -split "%3D")[1].Split("&")[0]

            $unpauseuri = "http://$PRTGServer/api/pause.htm?id=" + $newdeviceid + '&action=1&username=' + $Credential.UserName + '&password=' + $credential.GetNetworkCredential().password
        
            try{

                # Make API request to unpause newly created device
                Write-Verbose "Trying to unpause $Name"
                $unpauseapicall = Invoke-webrequest -method post -Uri $unpauseuri

            }# try end
        
            catch{
            
                $exceptionDetails = $_.Exception
                Write-Host "Error Invoking UnPause Request"
                throw $exceptionDetails
 
            }# catch end

            # Return new device name and id
            $result = [PSCustomObject] @{
                    'DeviceName' = $Name
                    'DeviceID' = $newdeviceid
            }# result end

            $results += $result

        }# foreach end
    }# process end

    end{
        return $results
    }# end end

}# function end