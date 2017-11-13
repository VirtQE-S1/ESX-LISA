###############################################################################
##
## Description:
##   Check open-vm-tools  status in vm and vCenter and stop vmtoolsd.service
##   Check status again,if are same twice,then passed,else error.
##
###############################################################################
## 
## Revision:
## v1.0 - junfwang - 9/18/2017 - Check vmtools status synced with guest.
## v1.1 - junfwang - 11/10/2017 - Change name and instead $Result of $retVal
##
###############################################################################


<#
.Synopsis
    check open-vm-tools

.Description
    check vmtools status synced with guest.
    
 <test>
     <testName>ovt_stop_start_synced_with_gui</testName>      
     <testID>ESX-OVT-25</testID>
     <testScript>testScripts\ovt_stop_start_synced_with_gui.ps1</testScript>
     <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
     <timeout>200</timeout>
     <testparams>
            <param>TC_COVERED=RHEL6-34907,RHEL7-50889</param>
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

#
# main script code
#

$Result = $Failed
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj){
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    exit
}
# Get guest version
$DISTRO = ""
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ( $DISTRO -eq "RedHat6" ){
    DisconnectWithVIServer
    return $Skipped
    Exit
}
#
#  Stop OVt and Check OVT status in VM
#
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl stop vmtoolsd"       
$vmtoolsDeadInVm = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl status vmtoolsd |grep dead"
#
# Wait OVT status change in host
#
$timeout1 = 60
while ($timeout1 -gt 0)
{   
    $vmtoolsDeadStatusInHost =  Get-VMHost -Name $hvServer | Get-VM -Name $vmName | Select-Object Name,@{Name="toolstatus";Expression={$_.ExtensionData.guest.toolsRunningStatus}}
    $vmtoolsRunningInHost = $null
    $vmtoolsDeadInHost = $null
    if ($vmtoolsDeadStatusInHost.Name -eq $vmName){
        $vmtoolsDeadInHost=$vmtoolsDeadStatusInHost.toolstatus
    }  
    if ($vmtoolsDeadInHost -eq "guestToolsNotRunning" ){
        break
    }
    Start-Sleep -S 1
    $timeout1 = $timeout1 - 1 
    if ($timeout1 -eq 0)
    {
        Write-Host -F Red "WARNING: Timeout to check vmtools in the host"
        Write-Output "WARNING: Timeout to check vmtools in the host"
        break
    }
}
#
#  Start OVt and Check OVT status in VM
#             
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl start vmtoolsd"
$vmtoolsRunningInVm = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl status vmtoolsd |grep running"
#
# Wait OVT status change in host
#
$timeout2 = 60
while ($timeout2 -gt 0)
{   
    $vmtoolsRunningStatusInHost = Get-VMHost -Name $hvServer  |Get-VM -Name $vmName  | Select-Object Name,@{Name="toolstatus";Expression={$_.EXtensionData.guest.toolsRunningStatus}}
    $vmtoolsRunningInHost = $null
    if ($vmtoolsRunningStatusInHost.Name -eq $vmName){
        $vmtoolsRunningInHost=$vmtoolsRunningStatusInHost.toolstatus
    }
    if ($vmtoolsRunningInHost -eq "guestToolsRunning"){
        break
    }
    Start-Sleep -S 1
    $timeout2 = $timeout2 - 1
    
    if ($timeout2 -eq 0)
    {
        Write-Host -F Red "WARNING: Timeout to check vmtools in the host"
        Write-Output "WARNING: Timeout to check vmtools in the host"
        break
    }
}

    
if ($vmtoolsDeadInVm -ne $null ){
    if($vmtoolsDeadInHost -eq "guestToolsNotRunning" ){
        if($vmtoolsRunningInVm -ne $null){
            if($vmtoolsRunningInHost -eq "guestToolsRunning"){
                Write-Output "Pass : vmtools status are the same when start and stop vmtoolsd"
                $retVal=$Passed
            }
            else{
                 Write-Output "Error : after start vmtooldsd,vmtools status in host is not running"
                 $retVal=$Aborted
            }
        }
        else{
            Write-Output "Error :after start vmtooldsd,vmtools status in vm is not running "
            $retVal=$Aborted
        }
    }
    else {
         Write-Output "Error :after stop,vmtools status in host not the dead" 
         $retVal=$Aborted
    }
}
else{
    Write-Output "Error :after stop,vmtools status in vm not the dead"
    $retVal=$Aborted
}
"Info : ovt_check_vmtools_status_synced_with_guest_stop_start.ps1 script completed"
DisconnectWithVIServer
return $retVal
