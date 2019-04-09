###############################################################################
##
## Description:
## Test disks works well when hot add LSILogicSAS scsi disks.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 03/28/2019 - Hot add LSILogicSAS scsi disk.
##
## 
###############################################################################

<#
.Synopsis
    Hot add two scsi disk.
.Description

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

# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
#hot add LSI Logic scsi disk
$hd_size = Get-Random -Minimum 5 -Maximum 10
#$disk =  New-HardDisk -CapacityGB $hd_size -VM $vmObj -StorageFormat "Thin" -Controller "SCSI Controller 1"
New-HardDisk -VM $vmObj -CapacityGB $hd_size -StorageFormat "Thin" -Controller "SCSI Controller 1"

#
# Check the disk number of the guest.
#
$diskList =  Get-HardDisk -VM $vmObj
$diskLength = $diskList.Length

if ($diskLength -eq 3)
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Hot plug LSILogicSAS disk successfully, The disk count is $diskLength."
}
else
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Hot plug LSILogicSAS disk Failed, only $diskLength disk in guest."
    DisconnectWithVIServer
    return $Aborted
}

$result = SendCommandToVM $ipv4 $sshKey "rescan-scsi-bus.sh -a && ls /dev/sdc"
if (-not $result)
{
	Write-Host -F Red "FAIL: Failed to detect new add LSILogicSAS scsi disk."
	Write-Output "FAIL: Failed to detect new add LSILogicSAS scsi disk"
	$retVal = $Failed
}
else
{
	Write-Host -F Green "PASS: new add LSILogicSAS scsi disk could be detected."
    Write-Output "PASS: new add LSILogicSAS scsi disk could be detected."
    $retVal = $Passed
}

DisconnectWithVIServer

return $retVal
