###############################################################################
##
## Description:
## Test disks works well when hot add LSILogicParallel scsi disks.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 03/29/2019 - Hot add LSILogicParallel scsi disk.
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
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}

# Get the Guest B
$GuestBName = $vmObj.Name.Split('-')
# Get another VM by change Name
$GuestBName[-1] = "B"
$GuestBName = $GuestBName -join "-"
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName


# Add LSI Logic Parallel for Guest B
$hd_size = Get-Random -Minimum 1 -Maximum 5
# New-HardDisk -VM $GuestB -CapacityGB $hd_size -StorageFormat "Thin" | New-ScsiController -Type VirtualLsiLogic
$GuestB | New-HardDisk -CapacityGB $hd_size -StorageFormat "Thin" | New-ScsiController -Type VirtualLsiLogic
if (-not $?) {
    LogPrint "ERROR : Cannot add disk to VMB"
    DisconnectWithVIServer
    return $Aborted
}

# Start GuestB
Start-VM -VM $GuestB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}


# Wait for GuestB SSH ready
if ( -not (WaitForVMSSHReady $GuestBName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH"


# Get VMB IP addr
$ipv4Addr_B = GetIPv4 -vmName $GuestBName -hvServer $hvServer
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName 


#hot add LSI Logic Parallel scsi disk
$hd_size = Get-Random -Minimum 6 -Maximum 10
New-HardDisk -VM $GuestB -CapacityGB $hd_size -StorageFormat "Thin" -Controller "SCSI Controller 0"
if (-not $?) {
    LogPrint "ERROR : Cannot hot add disk to VMB"
    DisconnectWithVIServer
    return $Aborted
}

#
# Check the disk number of the guest.
#
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName

$diskList =  Get-HardDisk -VM $GuestB
$diskLength = $diskList.Length

if ($diskLength -eq 3)
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Hot plug LSILogicParallel scsi disk successfully, The disk count is $diskLength."
}
else
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Hot plug LSILogicParallel scsi disk Failed, only $diskLength disk in guest."
    DisconnectWithVIServer
    return $Aborted
}

$result = SendCommandToVM $ipv4Addr_B $sshKey "rescan-scsi-bus.sh -a && sleep 3 && ls /dev/sdc"
if (-not $result)
{
	Write-Host -F Red "FAIL: Failed to detect new add LSILogicParallel scsi disk.$result"
	Write-Output "FAIL: Failed to detect new add LSILogicParallel scsi disk $result"
	$retVal = $Failed
}
else
{
	Write-Host -F Green "PASS: new add LSILogicParallel scsi disk could be detected.$result"
    Write-Output "PASS: new add LSILogicParallel scsi disk could be detected.$result"
    $retVal = $Passed
}


DisconnectWithVIServer

return $retVal
