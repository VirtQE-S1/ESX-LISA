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

        $vmtoolsStatusInHost =  Get-VMHost -Name $hvServer | Get-VM -Name $vmName Get-View | Select Name,@{Name="toolstatus";Expression={$_.summary.guest.toolsRunningStatus}}
        $vmtoolsInHost = $null
        if ($vmtoolsStatusInHost.Name -eq $vmName){
            $vmtoolsInHost=$vmtoolsStatusInHost.toolstatus
        }  
        if ($vmtoolsInHost -eq $guestToolsNotRunning){
            $vmtoolsStart = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl start vmtoolsd"
        }
    
        $vmtoolsEraseStatusInHost =  Get-VMHost -Name $hvServer | Get-VM -Name $vmName Get-View | Select Name,@{Name="toolstatus";Expression={$_.summary.guest.toolsRunningStatus}}
        $vmtoolsDeadInHost = $null
        if ($vmtoolsEraseStatusInHost.Name -eq $vmName){
            $vmtoolsEraseInHost=$vmtoolsEraseStatusInHost.toolstatus
        }    
        if ($vmtoolsInHost -eq $guestToolsNotRunning){
            $Result=$Passed
        }
        else{
            $Result=$Failed
        } 
    }
}
"Info : ovt_check_vmtools_status_synced_with_guest_install_uninstall.ps1 script completed"
DisconnectWithVIServer
return $Result
