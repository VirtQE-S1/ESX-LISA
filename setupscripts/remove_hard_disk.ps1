###############################################################################
##
## Description:
##   This script will remove hard disk from VM
###############################################################################
##
## Revision:
## v1.0 - xuli - 01/16/2017 - Draft script for remove hard disk.
##
###############################################################################
<#
.Synopsis
    This script will remove hard disk from VM.

.Description
    The script will remove all the .vhdk disks from VM, except system disk.

    The .xml entry to specify this cleanup script would be:

        <cleanupScript>SetupScripts\remove_hard_disk.ps1</cleanupScript>

    The scripts will always pass the vmName, hvServer, and a
    string of testParams from the test definition separated by
    semicolons. The testParams for this script identify disk
    type, size, format

    A typical XML definition for this test case would look similar
    to the following:

    <test>
        <testName>HotAdd_SCSI_Dynamic</testName>
        <testID>ESX-STOR-001</testID>
        <setupScript>SetupScripts\add_hard_disk.ps1</setupScript>
        <testScript>stor_lis_disk.sh</testScript>
        <files>remote-scripts/stor_lis_disk.sh,remote-scripts/utils.sh,
        remote-scripts/stor_utils.sh </files>
        <cleanupScript>SetupScripts\remove_hard_disk.ps1</cleanupScript>
        <timeout>18000</timeout>
        <testparams>
            <param>DiskType=SCSI</param>
            <param>StorageFormat=Thin</param>
            <param>CapacityGB=3</param>
            <param>filesSystems=(ext4 ext3 xfs)</param>
        </testparams>
        <onError>Continue</onError>
    </test>

.Parameter vmName
    Name of the VM to remove disk from.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    setupScripts\remove_hard_disk
#>

param([string] $vmName, [string] $hvServer, [string] $testParams)

############################################################################
#
# Main entry point for script
#
############################################################################
# Check input arguments
#
if ($vmName -eq $null -or $vmName.Length -eq 0)
{
    "Error: VM name is null"
    return $False
}

if ($testParams -eq $null -or $testParams.Length -lt 3)
{
    "Error: No testParams provided"
    return $False
}
#
# VM system disk is named "Hard disk 1", NO changed anymore
#
$retVal = $Failed
$sysDisk = "Hard disk 1"
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName

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
    Write-Output "PASS: Clean disk new added successfully"
    $retVal = $Passed
}
else
{
    Write-Output "FAIL: Clean disk new added unsuccessfully"
}
return $retVal