###############################################################################
##
## Description:
##   This script will remove all cd drive on VM
###############################################################################
##
## Revision:
## v1.0 - ldu - 07/23/2018 - Draft script for remove cd driver.
##
###############################################################################
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

param([string] $vmName, [string] $hvServer, [string] $testParams)

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
		# "rootDir"		{ $rootDir = $fields[1].Trim() }
		# "sshKey"		{ $sshKey = $fields[1].Trim() }
		# "ipv4"			{ $ipv4 = $fields[1].Trim() }
		# "TestLogDir"	{ $logdir = $fields[1].Trim()}
		default			{}
    }
}

###############################################################################
#
# Main Body
#
###############################################################################
$retVal = $Failed
#
# VM is in powered off status, as a setup script to remove CD driver.
#
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
#
#remove CD driver to host
#
$cd = Get-CDDrive -VM $vmObj
$remove_cd = Remove-CDDrive -CD $cd -Confirm:$false

#check the cd removed successfully or not.
$CDList =  Get-CDDrive -VM $vmObj
$CDLength = $CDList.Length

if ($CDLength -eq 0)
{
    write-host -F Red "The cd driver count is $CDLength "
    Write-Output "Remove cd driver successfully"
    $retVal = $Passed
}
else
{
    write-host -F Red "The cd driver count is $CDLength "
    Write-Output "Remove cd driver during cleanScript Failed, only $CDLength cd in guest."
    DisconnectWithVIServer
    return $retVal
}
return $retVal
