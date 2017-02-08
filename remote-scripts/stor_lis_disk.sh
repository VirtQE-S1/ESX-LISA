#!/bin/bash
###############################################################################
##
## Description:
##   This script checks disk size, fdisk, mkfs, mount file system.
##   There should fdisk, mkfs, mount, umount should be succesful.
##
###############################################################################
##
## Revision:
## v1.0 - xuli - 01/09/2017 - Draft script for case stor_lis_disk.sh
## v1.1 - xuli - 01/20/2017 - Update check call trace as final step
###############################################################################
dos2unix utils.sh
# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}
# Source constants file and initialize most common variables
UtilsInit
#
# Start the testing
#
UpdateSummary "$(uname -a)"

dos2unix stor_utils.sh
# Source stor_utils.sh
. stor_utils.sh || {
    LogMsg "Error: unable to source stor_utils.sh!"
    UpdateSummary "Error: unable to source stor_utils.sh!"
    SetTestStateAborted
    exit 1
}

#Check for CapacityGB
if [ ! ${CapacityGB} ]; then
    LogMsg "Error: The CapacityGB variable is not defined."
    UpdateSummary "Error: The CapacityGB variable is not defined."
    SetTestStateAborted
    exit 1
fi
# when add 1G disk, 1073741824 shows in fdisk
dynamicDiskSize=$(($CapacityGB*1024*1024*1024))

CheckDiskCount
if [ "$?" != "0" ];then
    UpdateSummary "disk count check failed "
    SetTestStateFailed
    exit 1
else
    LogMsg "disk count check successfully "
fi

# check disk size
CheckDiskSize $driveName $dynamicDiskSize
if [ "$?" != "0" ]; then
    UpdateSummary "Error in check disk size"
    SetTestStateFailed
    exit 1
else
    LogMsg "disk size check successfully "
fi

# If does not define file system type, use ext3 as default.
if  [ ! ${fileSystems} ];then
    fileSystems=(ext3)
fi

if  [ ! $diskFormatType ];then
    LogMsg "will use fdisk command to format disk"
else
    LogMsg "will use $diskFormatType command to format disk"
fi

TestMultiplFileSystems ${fileSystems[@]} $diskFormatType
if [ "$?" != "0" ]; then
    UpdateSummary "Disk file test failed "
    LogMsg "Disk file test failed."
    SetTestStateFailed
    exit 1
else
    UpdateSummary "Disk file test Successfully "
    LogMsg "Disk file test Successfully."
fi
# Check for call trace log
CheckCallTrace
if [ "$?" != "0" ]; then
    UpdateSummary "Call trace exists during testing"
    SetTestStateFailed
    exit 1
else
    UpdateSummary "No call trace during testing"
    SetTestStateCompleted
    exit 0
fi
