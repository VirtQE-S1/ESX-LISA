########################################################################################
## Description:
##   Remove all cd drive on VM.
##
## Revision:
## 	v1.0.0 - ldu - 07/23/2018 - Draft script for remove cd driver.
## 	v1.1.0 - boyang - 03/02/2020 - Enhance CD object check and output.
########################################################################################


<#
.Synopsis
    This script will add cd drive to VM.

.Description
    This script will add cd drive to VM.

.Parameter vmName
    Name of the VM to remove disk from.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.

#>


# Checking the input arguments
param([string] $vmName, [string] $hvServer, [string] $testParams)
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


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse test parameters
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
		# "rootDir"		{ $rootDir = $fields[1].Trim() }
		# "sshKey"		{ $sshKey = $fields[1].Trim() }
		# "ipv4"			{ $ipv4 = $fields[1].Trim() }
		# "TestLogDir"	{ $logdir = $fields[1].Trim()}
		default			{}
    }
}


# Source the tcutils.ps1 file
. .\setupscripts\tcutils.ps1

PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
    $env:ENVVISUSERNAME `
    $env:ENVVISPASSWORD `
    $env:ENVVISPROTOCOL


########################################################################################
# Main Body
########################################################################################
$retVal = $Failed


# VM is in powered off status, as a setup script to remove CD driver.
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}


# Confirm CD exists or not.
$cd = Get-CDDrive -VM $vmObj
if ($null -eq $cd)
{
    LogPrint "ERROR: CD of VM is null."
    return $retVal
}


# Remove CD
$remove_cd = Remove-CDDrive -CD $cd -Confirm:$false


# Check the cd removed successfully or not.
$CDList =  Get-CDDrive -VM $vmObj
$CDLength = $CDList.Length
LogPrint "DEBUG: CDLength: ${CDLength}."
if ($CDLength -eq 0)
{
    LogPrint "INFO: Remove cd driver successfully."
    $retVal = $Passed
}
else
{
    LogPrint "INFO: Remove cd driver failed."
    DisconnectWithVIServer
    return $retVal
}


return $retVal
