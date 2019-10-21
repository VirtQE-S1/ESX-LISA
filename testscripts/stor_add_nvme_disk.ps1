########################################################################################
## Description:
##  Test disks works well when add a NVMe controller and disk to the Guest
##
## Revision:
##  v1.0.0 - ldu - 10/17/2019 - Build scripts.
##  v1.1.0 - boyang - 10/21/2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
     [virtual storage]Add a NVMe controller and disk to the Guest
.Description
        <test>
            <testName>stor_add_nvme_disk</testName>
            <testID>ESX-Stor-017</testID>
            <setupScript>setupscripts\add_hard_disk.ps1</setupScript>
            <testScript>testscripts\stor_add_nvme_disk.ps1</testScript>
            <files>remote-scripts/utils.sh</files>
            <files>remote-scripts/stor_add_nvme_disk.sh</files>
            <testParams>
                <param>DiskType=NVMe</param>
                <param>StorageFormat=Thick</param>
                <param>DiskDataStore=NVMe</param>
                <param>CapacityGB=5</param>
                <param>disk=/dev/nvme0n1</param>
                <param>FS=ext4</param>
                <param>TC_COVERED=RHEL6-0000,RHEL-144415</param>
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
# Checking the input arguments
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
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim()}
		default			{}
    }
}


# Check all parameters are valid
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


# Source tcutils.ps1
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


$skip = SkipTestInHost $hvServer "6.0.0","6.5.0","6.7.0"
if($skip)
{
    return $Skipped
}


# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName


# Check the disk number of the guest.
$diskList =  Get-HardDisk -VM $vmObj
$diskLength = $diskList.Length

if ($diskLength -eq 2)
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Setup add NVMe disk successfully, The disk count is $diskLength."
}
else
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Setup add NVMe disk Failed, only $diskLength disk in guest."
    DisconnectWithVIServer
    return $Aborted
}

$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix stor_add_nvme_disk.sh && chmod u+x stor_add_nvme_disk.sh && ./stor_add_nvme_disk.sh"
if (-not $result)
{
	Write-Host -F Red "FAIL:Failed to format new add NVMe disk."
	Write-Output "FAIL: Failed to format new add NVMe disk"
	$retVal = $Failed
}
else
{
	Write-Host -F Green "PASS:  new add NVMe disk could be format."
    Write-Output "PASS:  new add NVMe disk could be format."
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
