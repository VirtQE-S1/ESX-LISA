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
$nic_driver = "Vmxnet3"

#
# Tool ethtool checks NIC type
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message "nw_boot_vmxnet3.ps1: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
	return $Aborted
}

$nic_type = (Get-NetworkAdapter -VM $vmOut).Type

if ($nic_type -eq $nic_driver)
{
    $error_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg | grep 'Call Trace'"
    if ($null -eq $error_check)
    {
        Write-Host -F red "PASS: VM's NIC is $nic_type, and NO call trace FOUND after boot"
        Write-Output "PASS: VM's NIC is $nic_type, and NO call trace FOUND after boot"
        $retVal = $Passed
    }
    else
    {
        Write-Output "FAIL: VM's NIC is $nic_type, and call trace FOUND after boot"
        $retVal = $Failed
    }
}
else
{
    Write-Output "FAIL: VM's NIC is $nic_type, WON'T be covered in test scope"
    $retVal = $Failed
}

DisconnectWithVIServer
return $retVal