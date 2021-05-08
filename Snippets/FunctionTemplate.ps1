function Test-Function{
 
<#
.SYNOPSIS
    A brief description of the function.
 
.DESCRIPTION
    A detailed description of the function.
 
.PARAMETER  ParameterA
    The description of the ParameterA parameter.
 
.PARAMETER  ParameterB
    The description of the ParameterB parameter.
 
.EXAMPLE
    PS C:> Get-Something -ParameterA 'One value' -ParameterB 32
 
.EXAMPLE
    PS C:> Get-Something 'One value' 32
 
.INPUTS
    System.String,System.Int32
 
.OUTPUTS
    System.String
 
.NOTES
    Additional information about the function go here.
 
.LINK
    about_functions_advanced
 
.LINK
    about_comment_based_help
 
#>
 
    [CmdletBinding()]
    param(
 
        # parameter options
        # validation
        # cast
        # name and default value
 
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,
 
        [Parameter(Position=1)]
        [ValidateNotNull()]
        [System.Int32]
        $Index
 
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
 
        Do-Something
    }# begin end
 
    # This block is used to provide record-by-record processing for the function.
    process{
 
        try{
 
        }# try end
 
        catch{
 
            throw
 
        }# catch end
 
        finally{
 
        }# finally end
    }# process end
 
    # This block is used to provide optional one-time post-processing for the function.
    end{
 
    }# end end
}# function end