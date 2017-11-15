###############################################################################
##
## Description:
##   Check open-vm-tools status in vCenter if not running start first and 
##   erase vmtools
##   Check status again,if not running,then passed,else error.
##
###############################################################################
## 
## Revision:
##   v1.0 - junfwang - 9/18/2017 - Check vmtools status in vCenter is right 
##   or not.
##   v1.1 - junfwang - 11/13/2017 - add time wait the vmtools status to change 
##
##
###############################################################################


<#
.Synopsis
    check open-vm-tools

.Description
    check vmtools status in vCenter and VM.

 <test>
    <testName>ovt_install_uninstall_synced_with_gui</testName>      
    <testID>ESX-OVT-26</testID>
    <testScript>testScripts\ovt_install_uninstall_synced_with_gui.ps1</testScript>
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

###############################################################################
#
# main script code
#
###############################################################################

$Result = $Failed
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj){
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    Exit
}


#
# Get guest version
#

$DISTRO = ""
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ( $DISTRO -eq "RedHat6" ){
    DisconnectWithVIServer
    return $Skipped
    Exit
}

#
# Check OVT status in vCenter
#

$vmtoolsStatusInHost =  Get-VMHost -Name $hvServer | Get-VM -Name $vmName | Select-Object Name,@{Name="toolstatus";Expression={$_.ExtensionData.summary.guest.toolsVersionStatus}}
$vmtoolsInHost = $null
if ($vmtoolsStatusInHost.Name -eq $vmName){
    $vmtoolsInHost=$vmtoolsStatusInHost.toolstatus
}
if ($vmtoolsInHost -eq "guestToolsNotInstalled"){
   DisconnectWithVIServer
   return $Aborted
   Exit
}

#
# remove OVT
#

bin\plink.exe -i ssh\${sshKey} root@${ipv4} "yum erase open-vm-tools -y"

#
# wait the status in host change
#

$timeout = 60
while ($timeout -gt 0)
{   
    $vmtoolsEraseStatusInHost =  Get-VMHost -Name $hvServer | Get-VM -Name $vmName | Select-Object Name,@{Name="toolstatus";Expression={$_.ExtensionData.summary.guest.toolsVersionStatus}}
    $vmtoolsEraseInHost = $null
    if ($vmtoolsEraseStatusInHost.Name -eq $vmName){
        $vmtoolsEraseInHost=$vmtoolsEraseStatusInHost.toolstatus
    }  
    if ($vmtoolsEraseInHost -eq "guestToolsNotInstalled" ){
        break
    }
    Start-Sleep -S 1
    $timeout = $timeout - 1 
    if ($timeout -eq 0)
    {
        Write-Host -F Red "WARNING: Timeout to check vmtools in the host"
        Write-Output "WARNING: Timeout to check vmtools in the host"
        break
    }
}

#
# check OVT status after uninstall OVT
#

if ($vmtoolsEraseInHost -eq "guestToolsNotInstalled"){
    Write-Output "Pass :after uninstall,vmtools status in host is uninstalled"
    $retVal=$Passed
}
else{
    Write-Output "Error :after uninstall,vmtools status in host is not uninstalled"
    $retVal=$Failed
}

"Info : ovt_install_uninstall_synced_with_gui.ps1 script completed"
DisconnectWithVIServer
return $retVal
