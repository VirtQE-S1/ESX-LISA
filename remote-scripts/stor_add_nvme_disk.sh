#!/bin/bash

###############################################################################
##
## Description:
##  Test the guest works well after add NVMe controller and disk.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 8/28/2018 - Build the script
##
###############################################################################
# <test>
#     <testName>stor_add_nvme_disk</testName>
#     <testID>ESX-Stor-017</testID>
#     <setupScript>setupscripts\add_hard_disk.ps1</setupScript>
#     <testScript>stor_add_nvme_disk.sh</testScript  >
#     <files>remote-scripts/utils.sh</files>
#     <files>remote-scripts/stor_add_nvme_disk.sh</files>
#     <testParams>
#         <param>DiskType=NVMe</param>
#         <param>StorageFormat=Thick</param>
#         <param>DiskDataStore=NVMe</param>
#         <param>CapacityGB=5</param>
#         <param>disk=/dev/nvme0n1</param>
#         <param>FS=ext4</param>
#         <param>TC_COVERED=RHEL6-0000,RHEL-144415</param>
#     </testParams>
#     <cleanupScript>SetupScripts\remove_hard_disk.ps1</cleanupScript>
#     <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
#     <timeout>600</timeout>
#     <onError>Continue</onError>
#     <noReboot>False</noReboot>
# </test>

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
	echo "Error: unable to source utils.sh!"
	exit 1
}

# Source constants.sh to get all paramters from XML <testParams>
. constants.sh || {
	echo "Error: unable to source constants.sh!"
	exit 1
}

# Source constants file and initialize most common variables
UtilsInit

# Source stor_utils.sh

###############################################################################
##
## Main
##
###############################################################################
#Check the new added Test disk /dev/$disk exist.
ls $disk
if [ ! "$?" -eq 0 ]; then
	LogMsg "Test Failed.Test disk /dev/$disk not exist."
	UpdateSummary "Test failed.Test disk /dev/$disk not exist."
	SetTestStateAborted
	exit 1
else
	LogMsg " Test disk /dev/$disk exist."
	UpdateSummary "Test disk /dev/$disk exist."
fi

# Do Partition for Test disk if needed.
fdisk $disk <<EOF
        n
        p
        1


        w
EOF

# Get new partition
kpartx $disk

# Wait a while
sleep 6

# Format with file system
disk="${disk}p1"
mkfs.$FS $disk
UpdateSummary "format with $FS filesystem"
#Mount  disk to /$disk.
mkdir /test
mount $disk /test
if [ ! "$?" -eq 0 ]; then
	LogMsg "Mount Failed"
	UpdateSummary "FAIL: Mount Failed"
	SetTestStateAborted
	exit 1
else
	LogMsg "Mount disk successfully"
	UpdateSummary "Passed: Mount disk successfully"
fi

#Create test file in new added nvme disk.
touch /test/test
cat /test/test
if [ $? -ne 0 ]; then
	LogMsg "create and read test file failed"
	UpdateSummary "create and read test file failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "create and read test file successfully"
	UpdateSummary "create and read test file successfully"
	SetTestStateCompleted
	exit 0
fi
