###############################################################################
##
## Description:
##  reboot and shutdown the VM
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 09/06/2017 - reboot and shutdown guest.
##V1.0 - ldu - 07/23/2018
###############################################################################

<#
.Synopsis
    reboot and shutdown the VM

.Description
    reboot and shutdowne the VM, NO call trace found

.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the VIServer hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)

#
# Checking the input arguments
#
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
    exit 100
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    exit 100
}

if (-not $testParams)
{
    Throw "FAIL: No test parameters specified"
}

#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"

#
# Parse test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$logdir = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim())
	{
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim()}
		default			{}
    }
}

#
# Check all parameters are valid
#
if (-not $rootDir)
{
	"Warn : no rootdir was specified"
    exit 100
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

if ($null -eq $sshKey)
{
	"FAIL: Test parameter sshKey was not specified"
	return $False
}

if ($null -eq $ipv4)
{
	"FAIL: Test parameter ipv4 was not specified"
	return $False
}

if ($null -eq $logdir)
{
	"FAIL: Test parameter logdir was not specified"
	return $False
}

#
# Source tcutils.ps1
#
. .\setupscripts\tcutils.ps1
PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL

###############################################################################
#
# Main Body
#
###############################################################################


$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ( $DISTRO -eq "RedHat6" ){
    DisconnectWithVIServer
    return $Skipped
}


$retVal = $Failed


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$vmObj_restart = Restart-VMGuest -VM $vmObj -Confirm:$False
$ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
if ( $ret -ne $true )
{
    Write-Output "Failed: Failed to start VM."
    write-host -F Red "Failed: Failed to start VM."
    return $Aborted
}
$exist = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "touch /root/test01"

$shutdown = Shutdown-VMGuest -VM $vmObj -Confirm:$False
Start-sleep 30
$vmObjShutdown = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$state = $vmObjShutdown.PowerState
if ($state -ne "PoweredOff")
{
    Write-Output "The vm status is not powered off, status is $state"
    write-host -F Red "Failed: Failed to shutdown VM."
}
else
{
    Write-Output "passed: the vm shutdown successfully,status is $state"
    $retVal = $Passed
}

DisconnectWithVIServer

return $retVal
