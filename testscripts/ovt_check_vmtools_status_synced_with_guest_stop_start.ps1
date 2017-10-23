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
##
###############################################################################


<#
.Synopsis
    check open-vm-tools

.Description
    check vmtools status synced with guest.

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
if (-not $vmObj)
{
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
}
else
{ 

# Get guest version
    $DISTRO = ""
    $modules_array = ""
    $DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
    if ( $DISTRO -eq "RedHat7" )
    {
        $modules_array = $rhel7_modules.split(",")

        $vmtoolsStop = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl stop vmtoolsd"
        
        $vmtoolsDeadInVm = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl status vmtoolsd |grep dead"
        
        $vmtoolsDeadStatusInHost =  Get-VMHost -Name $hvServer | Get-VM -Name $vmName Get-View | Select Name,@{Name="toolstatus";Expression={$_.summary.guest.toolsRunningStatus}}
        $vmtoolsDeadInHost = $null
        if ($vmtoolsDeadStatusInHost.Name -eq $vmName){
            $vmtoolsDeadInHost=$vmtoolsDeadStatusInHost.toolstatus
                                     }                                  
                                                    
        $vmtoolsStart = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl start vmtoolsd"

        $vmtoolsRunningInVm = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl status vmtoolsd |grep running"
    
        $vmtoolsRunningStatusInHost = Get-VMHost -Name $hvServer | Get-VM -Name $vmName Get-View | Select Name,@{Name="toolstatus";Expression={$_.summary.guest.toolsRunningStatus}}
        $vmtoolsRunningInHost = $null
        if ($vmtoolsRunningStatusInHost.Name -eq $vmName){
            $vmtoolsRunningInHost=$vmtoolsRunningStatusInHost.toolstatus
                                 }
    
        
    
        if ($vmtoolsDeadInVm -ne $null ){
            if($vmtoolsDeadInHost -eq $guestToolsNotRunning ){
                if($vmtoolsRunningInVm -ne $null){
                    if($vmtoolsRunningInHost -eq $guestToolsRunning){
                        Write-Output "Pass : vmtools status are the same when start and stop vmtoolsd"
                        $Result=$Passed
                    }
                    else{   
                        Write-Output "Error : after start vmtooldsd,vmtools status in host is not running"
                        $Result=$Failed
                    }
                }
                else{
                    Write-Output "Error :after start vmtooldsd,vmtools status in vm is not running"
                    $Result=$Aborted
                }
            }
            else {
                Write-Output "Error :after stop,vmtools status in host not the dead" 
                $Result=$Aborted   
            }
        }
        else
        {
            Write-Output "Error :after stop,vmtools status in vm not the dead"
            $Result=$Aborted
        }
    }
    else
    {
        "Error : Guest OS version is not RedHat7"
        $Result = $Skiped
    }
   

}

"Info : ovt_check_vmtools_status_synced_with_guest_stop_start.ps1 script completed"
DisconnectWithVIServer
return $Result
