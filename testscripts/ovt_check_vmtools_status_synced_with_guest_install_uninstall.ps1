###############################################################################
##
## Description:
##   Check open-vm-tools status in vCenter if not running start first and erase vmtools
##   Check status again,if not running,then passed,else error.
##
###############################################################################
## 
## Revision:
## v1.0 - junfwang - 9/18/2017 - Check vmtools status in vCenter is right or not.
##
###############################################################################


<#
.Synopsis
    check open-vm-tools

.Description
    check vmtools status in vCenter.
    
    <test>
     <testName>ovt_check_vmtools_status_synced_with_guest_install_uninstall</testName>      
     <testID>ESX-OVT-24</testID>
     <testScript>testScripts\ovt_check_vmtools_status_synced_with_guest_install_uninstall.ps1</testScript>
     <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
     <timeout>200</timeout>
     <testparams>
            <param>TC_COVERED=RHEL6-34899,RHEL7-50882</param>
     </testparams>
     <onError>Continue</onError>
 </test> 

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)
#
# Checking the input arguments
#
if (-not $vmName)
{
    "Error: VM name cannot be null!"
    exit
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}

#
# Display the test parameters so they are captured in the log file
#
"TestParams : '${testParams}'"

#
# Parse the test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "sshKey"       { $sshKey = $fields[1].Trim() }
    "rootDir"      { $rootDir = $fields[1].Trim() }
    "ipv4"         { $ipv4 = $fields[1].Trim() }
    default        {}
    }
}

if (-not $rootDir)
{
    "Warn : no rootdir was specified"
}
else
{
    if ( (Test-Path -Path "${rootDir}") )
    {
        cd $rootDir
    }
    else
    {
        "Warn : rootdir '${rootDir}' does not exist"
    }
}

#
# Source the tcutils.ps1 file
#
. .\setupscripts\tcutils.ps1

PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL

$Result = $Failed
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj){
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    Exit
}

#
# main script code
#

# Get guest version
$DISTRO = ""
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ( $DISTRO -eq "RedHat6" ){
    $Result=$Skipped
    DisconnectWithVIServer
    return $Result
    Exit
}

$vmtoolsStatusInHost =  Get-VMHost -Name $hvServer | Get-VM -Name $vmName | Select-Object Name,@{Name="toolstatus";Expression={$_.ExtensionData.guest.toolsRunningStatus}}
$vmtoolsInHost = $null

if ($vmtoolsStatusInHost.Name -eq $vmName){
    $vmtoolsInHost=$vmtoolsStatusInHost.toolstatus
}

if ($vmtoolsInHost -eq $null){
   $Result =$Aborted
   DisconnectWithVIServer
   return $Result
   Exit
}

bin\plink.exe -i ssh\${sshKey} root@${ipv4} "yum erase open-vm-tools -y"


$vmtoolsEraseStatusInHost =  Get-VMHost -Name $hvServer | Get-VM -Name $vmName | Select-Object Name,@{Name="toolstatus";Expression={$_.ExtensionData.summary.guest.toolsStatus}}
$vmtoolsEraseInHost = $null

if ($vmtoolsEraseStatusInHost.Name -eq $vmName){
    $vmtoolsEraseInHost=$vmtoolsEraseStatusInHost.toolstatus
}

if ($vmtoolsEraseInHost -eq "toolsNotInstalled"){
    Write-Output "Pass :after uninstall,vmtools status in host is uninstalled"
    $Result=$Passed
}
else{
    Write-Output "Error :after uninstall,vmtools status in host is not uninstalled"
    $Result=$Failed
}


"Info : ovt_check_vmtools_status_synced_with_guest_install_uninstall.ps1 script completed"
DisconnectWithVIServer
return $Result
