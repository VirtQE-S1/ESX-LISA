#!/bin/bash


###############################################################################
##
##  Description:
##      cp big files between different disk type.
##
##  Revision:
##      v1.0.0 - ldu - 7/26/2018 - Build the script
##      v1.0.1 - boyang - 05/10/2019 - Enhance debug info of script
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
## Main Body
##
###############################################################################


# Mount nfs disk to Guest
# NFS server is setup in ESXi ENV and test file - bigfile has been prepared
yum -y install nfs-utils
mkdir /nfs
mount $nfs /nfs
mount | grep $nfs
if [ ! "$?" -eq 0 ]; then
    LogMsg "ERROR: Mount NFS failed, check nfs server config by manual"
    UpdateSummary "ERROR: Mount NFS failed, check nfs server config by manual"
    SetTestStateAborted
    exit 1
else
    LogMsg "INFO: Mount NFS successfully"
    UpdateSummary "INFO: Mount NFS successfully"
fi


# Copy a big file more than 5G to scsi type disk
cp /nfs/bigfile /root
if [ ! "$?" -eq 0 ]; then
    LogMsg "ERROR: CP bigfile file to SCSI disk failed"
    UpdateSummary "ERROR: CP bigfile file to SCSI disk failed"
    SetTestStateFailed
    exit 1
else
    LogMsg "INFO: CP bigfile file to SCSI disk successfully"
    UpdateSummary "INFO: CP bigfile file to SCSI disk successfully"
fi


# Add a IDE disk to Guest and make filesystem on it
system_part=`df -h | grep /boot | awk 'NR==1' | awk '{print $1}'| grep a`
LogMsg "DEBUG: system_part: $system_part"
UpdateSummary "DEBUG: system_part: $system_part"


if [ ! $system_part ]; then
#   The IDE disk should be sda
    disk_name="sda"
else
#   The IDE disk should be sdb
    disk_name="sdb"
fi
LogMsg "DEBUG: disk_name: $disk_name"
UpdateSummary "DEBUG: disk_name: $disk_name"


# Do Partition for IDE disk.
fdisk /dev/"$disk_name" <<EOF
n
p
1


w
EOF


# Get new partition
kpartx /dev/"$disk_name"


# Format ext4
mkfs.ext4 /dev/${disk_name}1
if [ ! "$?" -eq 0 ]
then
    LogMsg "ERROR: Format failed"
    UpdateSummary "ERROR: Format failed"
    SetTestStateAborted
    exit 1
else
    LogMsg "INFO: Format successfully"
    UpdateSummary "INFO: Format successfully"
fi


# Mount IDE disk to /mnt
mount /dev/"$disk_name"1 /mnt
if [ ! "$?" -eq 0 ]
then
    LogMsg "ERROR: Mount Failed"
    UpdateSummary "ERROR: Mount failed"
    SetTestStateAborted
    exit 1
else
    LogMsg "INFO: Mount IDE disk successfully"
    UpdateSummary "INFO: Mount IDE disk successfully"
fi


# Copy file to IDE disk
cp /root/bigfile /mnt
if [ ! "$?" -eq 0 ]
then
    LogMsg "ERROR: Copy file from SCSI to IDE disk failed"
    UpdateSummary "ERROR: Copy file from SCSI to IDE disk failed"
    SetTestStateFailed
    exit 1
else
    LogMsg "INFO: SCP file from SCSI to IDE disk successfully"
    UpdateSummary "INFO: SCP file from SCSI to IDE disk successfully"
    SetTestStateCompleted
    exit 0
fi
