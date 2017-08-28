###############################################################################
##
## Description:
## Remove the vmxnet3 network adapter and reboot well
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 08/03/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Remove the vmxnet3 network adapter and reboot well

.Description
    When VM alives, remove vmxent3, no crash

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
$nic = "vmxnet3"

#
# Confirm VM
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message "nw_remove_vmxnet3.ps1: Unable to get-vm with $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
	return $Aborted
}

#
# Get VM NIC adapter after remove it
#
$adapter_count = (Get-NetworkAdapter -VM $vmOut).Count
$adapter_type = (Get-NetworkAdapter -VM $vmOut).Type
Write-Host -F red "count is $adapter_count and type is $adapter_type"
if ($adapter_count -eq 1 -and $adapter_type -ne "Vmxnet3")
{
    Write-Out "PASS: Remove adapter and reboot successfully."
	$retVal = $Passed
}

DisconnectWithVIServer

return $retVal