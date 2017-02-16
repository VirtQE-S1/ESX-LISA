##############################################################################
##
## Description:
##   This script will resize disk to new size.
##
###############################################################################
##
## Revision:
## v1.0 - xuli - 02/16/2017 - Draft script for resize hard disk.
##
###############################################################################
<#
.Synopsis
    This script will resize hard disk of VM.

.Description
    The script will resize vmdk file of vm.
    The .xml entry to specify this test script would be:
    <testScript>SetupScripts\stor_resize_disk.ps1</testScript>

   The scripts will always pass the vmName, hvServer, and a
   string of testParams from the test definition separated by
   semicolons. The testParams for this script identify DiskType, CapacityGB,
   StorageFormat.

   Where
        DiskType - IDE or SCSI, currently only supports SCSI
        StorageFormat - The format of new hard disk, can be (Thin, Thick,
        EagerZeroedThick)
        newCapacityGB - Capacity of the new virtual disk in gigabytes

    A typical XML definition for this test case would look similar
    to the following:

.Parameter vmName
    Name of the VM to add disk.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    testScripts\stor_resize_disk
#>
param ([String] $vmName, [String] $hvServer, [String] $testParams)
########################################################################
#
# Checking the input arguments
#

if (-not $vmName)
{
    "Error: no VMName was specified"
    exit
}

if (-not $hvServer)
{
    "Error: No hvServer was specified"
    exit
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}
#
# Display the test parameters so they are captured in the log file
#
"TestParams : '${testParams}'"

# Parse the testParams string
#
$diskType = $null
$storageFormat = $null
$newCapacityGB = $null
$rootDir    = $null
$TestLogDir = $null
$TestName   = $null

$params = $testParams.TrimEnd(";").Split(";")

foreach($p in $params){
    $fields = $p.Split("=")
    $key = $fields[0].Trim()
    $value = $fields[1].Trim()
    switch ($key)
    {
        "DiskType"        { $diskType    = $value }
        "StorageFormat"   { $storageFormat   = $value }
        "NewCapacityGB"   { $NewCapacityGB = $value }
        "SSHKey"          { $sshKey  = $value }
        "ipv4"            { $ipv4    = $value }
        "rootDir"         { $rootDir = $value }
        "TestLogDir"      { $TestLogDir = $value }
        "TestName"        { $TestName =$value }
        default     {}  # unknown param - just ignore it
    }
}

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

#
# Source the tcutils.ps1 file
#
. .\setupscripts\tcutils.ps1

PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL

$result = $Failed

if (@("Thin", "Thick", "EagerZeroedThick") -notcontains $storageFormat)
{
    "Error: Unknown StorageFormat type: $storageFormat"
}

if (@("IDE", "SCSI") -notcontains $diskType)
{
    "Error: Unknown StorageFormat type: $diskType"
}

"Info: partition/readwrite disk before resize"
$guest_script = "stor_lis_disk.sh"
##Make sure if we can perform Read/Write operations on the guest VM
$sts =  RunRemoteScript $guest_script
if( -not $sts[-1] ){
    "Error: Error while running $guest_script"
}

"Info: Resizing the VHDX to $newCapacityGB"
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$diskList =  Get-HardDisk -VM $vmObj

foreach ($disk in $diskList)
{
    $diskName= $disk.Name
    # keep the vm system disk not removed
    if ($diskName -ne "Hard disk 1")
    {
        $diskResize = Set-HardDisk -HardDisk $disk -Confirm:$false -CapacityGB:$newCapacityGB -ErrorAction SilentlyContinue
        if ( -not $diskResize)
        {
            "Error : Cannot resize hard disk of the VM $vmName"
        }
        else
        {
            write-output " Done: resize disk"
        }
    }
}

# rescan guest disk to make fdisk show with new size
$sta = SendCommandToVM $ipv4 $sshkey "echo 1 > /sys/block/sdb/device/rescan"
if (-not $sta)
{
    "Error : Cannot send command to rescan disk "
}

# replace newCapacityGB value to CapacityGB of constants.sh
$sta = SendCommandToVM $ipv4 $sshkey "sed -i  's/CapacityGB=[0-9]*/CapacityGB=$($newCapacityGB)/g' ~/constants.sh"
if (-not $sta)
{
    "Error : Cannot send command to set CapacityGB as new size"
}

"Info: partition/readwrite disk after resize"
$sts =  RunRemoteScript $guest_script
if(-not $sts[-1])
{
    "Error: Error while running $guest_script"
}
else
{
    $result = $Passed
}
"Info : stor_resize_disk script completed"
DisconnectWithVIServer
return $result
