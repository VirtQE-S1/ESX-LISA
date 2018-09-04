###############################################################################
##
## Description:
## Test disks works well when hot add scsi disks.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 08/31/2018 - Hot add scsi disk.
##
## 
###############################################################################

<#
.Synopsis
    Hot add two scsi disk.
.Description
<test>
            <testName>stor_hot_plug_scsi</testName>
            <testID>ESX-Stor-001</testID>
            <testScript>testscripts\stor_hot_plug_scsi.ps1</testScript  >
            <files>remote-scripts/utils.sh</files>
            <files>remote-scripts/stor_hot_plug_scsi_disk.sh</files>
            <testParams>
                <param>TC_COVERED=RHEL6-34927,RHEL7-50907</param>
            </testParams>
            <cleanupScript>SetupScripts\remove_hard_disk.ps1</cleanupScript>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>600</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
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
#hot add two scsi disk
$hd_size = Get-Random -Minimum 5 -Maximum 10
$disk1 = New-HardDisk -CapacityGB $hd_size -VM $vmObj -StorageFormat "Thin" -ErrorAction SilentlyContinue
# $disk2 = New-HardDisk -CapacityGB $hd_size -VM $vmObj -StorageFormat "Thin" -ErrorAction SilentlyContinue
#
# Check the disk number of the guest.
#
$diskList =  Get-HardDisk -VM $vmObj
$diskLength = $diskList.Length

if ($diskLength -eq 2)
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Add two disk successfully, The disk count is $diskLength."
}
else
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Add disk Failed, only $diskLength disk in guest."
    DisconnectWithVIServer
    return $Aborted
}

$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix stor_hot_plug_scsi_disk.sh && chmod u+x stor_hot_plug_scsi_disk.sh && ./stor_hot_plug_scsi_disk.sh"
if (-not $result)
{
	Write-Host -F Red "FAIL: Failed to format new add scsi disk."
	Write-Output "FAIL: Failed to format new add scsi disk"
	return $Aborted
}
else
{
	Write-Host -F Green "PASS: new add scsi disk could be formated and read,write."
    Write-Output "PASS: new add scsi disk could be formated and read,write."
    $retVal = $Passed
}

DisconnectWithVIServer

return $retVal
