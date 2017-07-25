###############################################################################
##
## Description:
##  Target VM boot with vmxnet3 driver and works
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 07/19/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Target VM boot with vmxnet3 driver and works

.Description
    Target VM boot well with vmxnet3, confirm vmxnet3 works

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
    exit
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    exit
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

$retVal = $Failed
$nic_driver = "vmxnet3"

#
# Tool ethtool checks NIC type
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message "nw_boot_vmxnet3.ps1: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
	return $Aborted

}

#
# Reboot VM with "init 6"
#
bin\plink.exe -i ssh\${sshKey} root@${ipv4} 'init 6'

$result = WaitForVMSSHReady $vmName $hvServer ${sshKey} 360
if ( $result -ne $true )
{
    Write-Host -F red "Debug: result is $result"
    Write-Error "WARNING: Boot VM failed. Please check it manualy"
	return $Aborted
}

#
# Confirm NIC interface types. RHELs has different NIC types, like "eth0" "ens192:" "enp0s25:" "eno167832:"
# After snapshot, defalut, NIC works and MTU is 1500
#
$eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"

Write-Output "Start to check VM's $nic_driver driver."
$result = SendCommandToVM $ipv4 $sshKey "ethtool -i $eth | grep $nic_driver"
if ($result)
{
    Write-Output "PASS: Check VM's $nic_driver passed"
    $retVal = $Passed
}

#
# Confirm NIC works after boot
#
$result = SendCommandToVM $ipv4 $sshKey "ping $hvServer -I $eth -c 4"
if (-not $result)
{
	Write-Output "FAIL: $nic_driver - $eth ping failed."
	DisconnectWithVIServer
	return $Aborted
}

DisconnectWithVIServer
return $retVal