#!/bin/bash

###############################################################################
##
## Description:
##   add IDE disk and check wheather it works
##
###############################################################################
##
## Revision:
## v1.0.0 - ruqin - 7/11/2018 - Build the script
##
###############################################################################

dos2unix utils.sh

#
# Source utils.sh
#
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

#
# Source constants file and initialize most common variables
#
UtilsInit

###############################################################################
##
## Put your test script here
## NOTES:
## 1. Please use LogMsg to output log to terminal.
## 2. Please use UpdateSummary to output log to summary.log file.
## 3. Please use SetTestStateFailed, SetTestStateAborted, SetTestStateCompleted,
##    and SetTestStateRunning to mark test status.
##
###############################################################################


# Do Partition for /dev/sdb

fdisk /dev/sdb <<EOF
n
p
1


w
EOF

# Format xfs

mkfs.xfs /dev/sdb1

if [ ! "$?" -eq 0 ]
then
    LogMsg "Format Failed"
    SetTestStateFailed
    exit 1
fi

mount /dev/sdb1 /mnt

if [ ! "$?" -eq 0 ]
then
    LogMsg "Mount Failed"
    SetTestStateFailed
    exit 1
fi

cd /mnt
touch test

if [ ! "$?" -eq 0 ]
then
    LogMsg "Create New File Failed"
    SetTestStateFailed
    exit 1
fi

file="/mnt/test"

if [ ! -f "$file" ]; then
    LogMsg "Create New File Failed"
    SetTestStateFailed
    exit 1
fi

SetTestStateCompleted
exit 0