#!/bin/bash
###############################################################################
##
## Description:
##   This script mounts nfs path to local /mnt, do dd file under /mnt,
## then umount path.
##
###############################################################################
##
## Revision:
## v1.0 - xuli - 02/04/2017 - Draft script for case stor_lis_nfs.sh
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

#Set the mount point and type
mountPoint="/mnt"
mountType="nfs"

#Check for NFS_Path
if [ ! ${NFS_Path} ]; then
    LogMsg "Error: The NFS_Path variable is not defined."
    UpdateSummary "Error: The NFS_Path variable is not defined."
    SetTestStateAborted
    exit 1
fi

#Restart nfs service
service nfs restart
if [ "$?" = "0" ]; then
    LogMsg "Nfs restart successfully..."
else
    LogMsg "Error in restart nfs..."
    UpdateSummary "Error in restart nfs..."
    SetTestStateFailed
    exit 1
fi

#Mount nfs_path to /mnt
DoMountFs $NFS_Path $mountPoint $mountType
if [ "$?" = "0" ]; then
    LogMsg "mount nfs path successfully "
else
    LogMsg "Error in mount nfs path"
    UpdateSummary "Error in mount nfs path"
    SetTestStateFailed
    exit 1
fi

#Create file under /mnt
DoDDFile "/dev/zero" "$mountPoint/data" "10M" "50"
#dd if=/dev/zero of=/mnt/data bs=10M count=50
if [ "$?" != "0" ]; then
    LogMsg "Error in dd file to $mountPoint"
    SetTestStateFailed
    exit 1
else
    LogMsg "Successfully in dd file to $mountPoint"
fi

#umount /mnt and clean up /mnt file
DoUMountFs $mountPoint "true"
if [ "$?" != "0" ]; then
    LogMsg "Error in umount $mountPoint or clean file"
    SetTestStateFailed
    exit 1
else
    LogMsg "Successfully in umount $mountPoint and clean file"
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
