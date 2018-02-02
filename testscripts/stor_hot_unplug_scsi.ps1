###############################################################################
##
## Description:
## Hot remove one scsi disk.
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 01/31/2018 - Hot unplug scsi disk in guest.
##
## ESX-Stor-004
###############################################################################

<#
.Synopsis
    Hot remove one scsi disk.
.Description
<test>
    <testName>stor_hot_unplug_scsi</testName>
    <testID>ESX-STOR-008</testID>
    <setupScript>SetupScripts\add_hard_disk.ps1</setupScript>
    <testScript>testscripts/stor_hot_unplug_scsi.ps1</testScript>
    <files>remote-scripts/stor_utils.sh </files>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <timeout>300</timeout>
    <testparams>
        <param>DiskType=SCSI</param>
        <param>StorageFormat=Thin</param>
        <param>CapacityGB=3</param>
        <param>TC_COVERED=RHEL6-34926,RHEL7-50906</param>
    </testparams>
    <onError>Continue</onError>
</test>

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
#The system disk
$sysDisk = "Hard disk 1"

#
# Check the disk number of the guest.
#
$diskList =  Get-HardDisk -VM $vmObj
$diskLength = $diskList.Length

if ($diskLength -gt 1)
{
    write-host -F Red "The disk count is $diskLength "
    Write-Output "Add disk successfully"
}
else
{
    write-host -F Red "The disk count is $diskLength "
    Write-Output "Add disk during setupScript Failed, only $diskLength disk in guest."
    DisconnectWithVIServer
    return $Aborted
}

while ($True)
{
    # How many disks in VM
    $diskList =  Get-HardDisk -VM $vmObj
    $diskLength = $diskList.Length

    # If disks counts great than 1, will delete them
    if ($diskList.Length -gt 1)
    {
        foreach ($disk in $diskList)
        {
            $diskName= $disk.Name
            if ($diskName -ne $sysDisk)
            {
                Get-HardDisk -VM $vmObj -Name $($diskName) | Remove-HardDisk -Confirm:$False -DeletePermanently:$True -ErrorAction SilentlyContinue
                # Get new counts of disks
                $diskNewLength = (Get-HardDisk -VM $vmObj).Length

                if (($diskLength - $diskNewLength) -eq 1)
                {
                    Write-Output "DONE: remove $diskName"
                    break
                }
            }
        }
    }
    else
    {
        Write-Output "DONE: Only system disk is left"
        break
    }
}

$diskLastList =  Get-HardDisk -VM $vmObj
if ($diskLastList.Length -eq 1)
{
    Write-Output "PASS: Hot remove disk new added successfully"
    $retVal = $Passed
}
else
{
    Write-Output "FAIL: Hot remove disk new added Failed"
}

DisconnectWithVIServer

return $retVal
