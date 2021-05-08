function Install-MSIFile {

  [CmdletBinding()]
  Param(
    [parameter(mandatory=$true,ValueFromPipeline=$true,ValueFromPipelinebyPropertyName=$true)]
        [ValidateNotNullorEmpty()]
        [string]$msiFile,

        [parameter()]
        [ValidateNotNullorEmpty()]
        [string]$targetDir
  )
  if (!(Test-Path $msiFile)){
    throw "Path to the MSI File $($msiFile) is invalid. Please supply a valid MSI file"
  }
  $arguments = @(
    "/i"
    "`"$msiFile`""
    "/qn"
    "/norestart"
  )
  if ($targetDir){
    if (!(Test-Path $targetDir)){
        throw "Path to the Installation Directory $($targetDir) is invalid. Please supply a valid installation directory"
    }
    $arguments += "INSTALLDIR=`"$targetDir`""
  }
  Write-Verbose "Installing $msiFile....."
  $process = Start-Process -FilePath msiexec.exe -ArgumentList $arguments -Wait -PassThru
  if ($process.ExitCode -eq 0){
    Write-Verbose "$msiFile has been successfully installed"
  }
  else {
    Write-Verbose "installer exit code  $($process.ExitCode) for file  $($msifile)"
  }
}

function Uninstall-MSIFile {

[CmdletBinding()]
Param(
[parameter(mandatory=$true,ValueFromPipeline=$true,ValueFromPipelinebyPropertyName=$true)]
[ValidateNotNullorEmpty()]
[string]$msiFile
)
if (!(Test-Path $msiFile)){
throw "Path to the MSI File $($msiFile) is invalid. Please supply a valid MSI file"
}
$arguments = @(
"/x"
"`"$msiFile`""
"/qn"
"/norestart"
)
Write-Verbose "Uninstalling $msiFile....."
$process = Start-Process -FilePath msiexec.exe -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -eq 0){
Write-Verbose "$msiFile has been successfully uninstalled"
}
else {
Write-Error "installer exit code  $($process.ExitCode) for file  $($msifile)"
}
}
