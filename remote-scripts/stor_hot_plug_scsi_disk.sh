#!/bin/bash

###############################################################################
##
## Description:
##  Test the disks works well after hot add scsi disk.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 8/31/2018 - Build the script
##
###############################################################################

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

###############################################################################
##
## Main
##
###############################################################################
#Check the new added Test disk exist.
disk=sdb
ls /dev/$disk
if [ ! "$?" -eq 0 ]; then
	LogMsg "Test Failed.Test disk /dev/sdb not exist."
	UpdateSummary "Test failed.Test disk /dev/sdb not exist."
	SetTestStateAborted
	exit 1
else
	LogMsg " Test disk /dev/sdb exist."
	UpdateSummary "Test disk /dev/sdb exist."
fi

# Do Partition for Test disk if needed.
fdisk /dev/$disk <<EOF
        n
        p
        1


        w
EOF

# Get new partition
kpartx /dev/$disk

# Wait a while
sleep 6

# Format with file system
disk="/dev/sdb1"
mkfs.xfs $disk
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

# Create test file in new added scsi disk.
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

