###############################################################################
##
## Description:
##   This script will add cd drive to VM
###############################################################################
##
## Revision:
## v1.1 - ldu - 07/23/2018 - Draft script for add cd driver.
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

$params = $testParams.Split(";")
foreach ($p in $params)
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim())
	{
        "cd_num"     { $cd_num = $fields[1].Trim() }
		default			{}
    }
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
#
# VM is in powered off status, as a setup script to add CD driver.
#
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
#
# add CD driver to host
#
$CDList =  Get-CDDrive -VM $vmObj
$current_cd = $CDList.Length
while ($current_cd -lt $cd_num )
{
    # $add_cd=New-CDDrive -VM $vmObj -ISOPath "[trigger]redhat/cloud-init.iso"
    $add_cd=New-CDDrive -VM $vmObj
    $current_cd=$current_cd+1
    Write-host -F Red "the current cd number is $current_cd "
}

#Check the CD drive add successfully
$CDList =  Get-CDDrive -VM $vmObj
$CDLength = $CDList.Length

if ($CDLength -eq $cd_num)
{
    write-host -F Red "The cd driver count is $CDLength "
    Write-Output "Add cd driver successfully"
    $retVal = $Passed
}
else
{
    write-host -F Red "The cd driver count is $CDLength "
    Write-Output "Add cd driver during setupScript Failed, only $CDLength cd in guest."
    DisconnectWithVIServer
    return $retVal
}
return $retVal
