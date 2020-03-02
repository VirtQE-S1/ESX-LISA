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


########################################################################################
# Main Body
########################################################################################
$retVal = $Failed


# VM is in powered off status, as a setup script to remove CD driver.
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName


# Remove CD driver to host
$cd = Get-CDDrive -VM $vmObj
if ($null -eq $cd)
{
    write-host -F Red "ERROR: CD of VM is null."
    Write-Output "ERROR: CD of VM is null."
    return $retVal
}


$remove_cd = Remove-CDDrive -CD $cd -Confirm:$false

# Check the cd removed successfully or not.
$CDList =  Get-CDDrive -VM $vmObj
$CDLength = $CDList.Length
Write-Host -F Red "DEBUG: CDLength: ${CDLength}"
Write-Output "DEBUG: CDLength: ${CDLength}"
if ($CDLength -eq 0)
{
    write-host -F Red "INFO: Remove cd driver successfully."
    Write-Output "INFO: Remove cd driver successfully."
    $retVal = $Passed
}
else
{
    write-host -F Red "INFO: Remove cd driver failed."
    Write-Output "INFO: Remove cd driver failed."
    DisconnectWithVIServer
    return $retVal
}


return $retVal
