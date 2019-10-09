#!/bin/bash

###############################################################################
##
## Description:
##  Format, make filesystem and mount new added disk. install fio package for later use.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 09/23/2019 - Build the script
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
#install fio packages for later test.
yum install fio -y
if [ ! "$?" -eq 0 ]; then
	LogMsg "Test Failed.Install fio tool failed."
	UpdateSummary "Test failed.Install fio tool failed."
	SetTestStateAborted
	exit 1
else
	LogMsg "Passed:Install fio tool successfully."
	UpdateSummary "Passed:Install fio tool successfully."
fi

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
mount $disk /mnt
if [ ! "$?" -eq 0 ]; then
	LogMsg "Mount Failed"
	UpdateSummary "FAIL: Mount Failed"
	SetTestStateAborted
	exit 1
else
	LogMsg "Mount disk successfully"
	UpdateSummary "Passed: Mount disk successfully"
fi

# set the nr_requests for the block driver queue to the lowest possible..
echo 4 > /sys/block/sdb/queue/nr_requests
if [ $? -ne 0 ]; then
	LogMsg "set the nr_requests for the block driver queue failed"
	UpdateSummary "set the nr_requests for the block driver queue failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "set the nr_requests for the block driver queue successfully"
	UpdateSummary "set the nr_requests for the block driver queue successfully"
	SetTestStateCompleted
	exit 0
fi

