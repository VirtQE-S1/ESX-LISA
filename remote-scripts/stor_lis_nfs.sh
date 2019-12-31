#!/bin/bash


########################################################################################
## Description:
##	Mounts nfs path to local /mnt, dd a file under /mnt, then umount path.
##
## Revision:
## 	v1.0.0 - xuli - 02/04/2017 - Draft script for case stor_lis_nfs.sh.
########################################################################################


# Source utils.sh
dos2unix utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


# Start the testing
UpdateSummary "$(uname -a)"


# Source stor_utils.sh
dos2unix stor_utils.sh
. stor_utils.sh || {
    LogMsg "Error: unable to source stor_utils.sh!"
    UpdateSummary "Error: unable to source stor_utils.sh!"
    SetTestStateAborted
    exit 1
}


#Set the mount point and type
mountPoint="/mnt"
mountType="nfs"


# Check for NFS_Path.
UpdateSummary "DEBUG: NFS_Path: $NFS_Path"
if [ ! ${NFS_Path} ]; then
    LogMsg "ERROR: The NFS_Path variable is not defined."
    UpdateSummary "ERROR: The NFS_Path variable is not defined."
    SetTestStateAborted
    exit 1
fi


# Mount nfs_path to /mnt.
DoMountFs $NFS_Path $mountPoint $mountType
if [ "$?" = "0" ]; then
    LogMsg "INFO: Mount nfs path successfully."
    UpdateSummary "INFO: Mount nfs path successfully."
else
    LogMsg "ERROR: Mount nfs path failed."
    UpdateSummary "ERROR: Mount nfs path failed."
    SetTestStateFailed
    exit 1
fi


# Create file under /mnt.
#dd if=/dev/zero of=/mnt/data bs=10M count=50
DoDDFile "/dev/zero" "$mountPoint/data" "10M" "50"
if [ "$?" = "0" ]; then
    LogMsg "INFO: Successfully in dd file to $mountPoint."
    UpdateSummary "INFO: Successfully in dd file to $mountPoint."
else
    LogMsg "ERROR: DD file to $mountPoint failed"
    UpdateSummary "ERROR: DD file to $mountPoint failed."
    SetTestStateFailed
    exit 1
fi


# Umount /mnt and clean up /mnt file
DoUMountFs $mountPoint "true"
if [ "$?" = "0" ]; then
    LogMsg "INFO: Successfully in umount $mountPoint and clean file."
    UpdateSummary "INFO: Successfully in umount $mountPoint and clean file."
else
    LogMsg "Error in umount $mountPoint or clean file."
    UpdateSummary "Error in umount $mountPoint or clean file."
    SetTestStateFailed
    exit 1
fi


# Check for call trace log
CheckCallTrace
if [ "$?" = "0" ]; then
    LogMsg "INFO: No call trace during testing."
    UpdateSummary "INFO: No call trace during testing."
    SetTestStateCompleted
    exit 0
else
    LogMsg "ERROR: Call trace exists during testing."
    UpdateSummary "ERROR: Call trace exists during testing."
    SetTestStateFailed
    exit 1
fi
