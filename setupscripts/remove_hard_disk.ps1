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
            <param>TC_COVERED=ESX-STOR-001</param>
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
# when there are multiple disks, after remove one, the name of disk will changed
# automatically, e.g. after remove "Hard disk 2", original hard disk name"Hard disk 3"
# will change to "Hard disk 2"
#

$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
while ($True)
{
    $diskList =  Get-HardDisk -VM $vmObj

    # exists more disk except system disk
    if ($diskList.Length -gt 1)
    {
        foreach ($disk in $diskList)
        {
            $diskName= $disk.Name
            # keep the vm system disk not removed
            if ($diskName -ne "Hard disk 1")
            {
                Get-HardDisk -VM $vmObj -Name $($diskName) | Remove-HardDisk -Confirm:$False -DeletePermanently:$True

            if ( -not $?)
            {
                Throw "Error : Cannot remove hard disk of the VM $vmName"
                return $False
            }
            else
            {
                write-output " Done: remove disk"
            }
            Start-Sleep -s 1
            # wait for name refresh, exit this loop and get the new disk list
            break;
            }
        }
    }
    else
    {
        write-output "Only one system disk left"
        break
    }
}

return $True
