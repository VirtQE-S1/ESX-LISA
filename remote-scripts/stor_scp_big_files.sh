#!/bin/bash

###############################################################################
##
## Description:
##   cp big files between different disk type.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 7/26/2018 - Build the script
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
## Put your test script here
## NOTES:
## 1. Please use LogMsg to output log to terminal.
## 2. Please use UpdateSummary to output log to summary.log file.
## 3. Please use SetTestStateFailed, SetTestStateAborted, SetTestStateCompleted,
##    and SetTestStateRunning to mark test status.
##
###############################################################################
#Mount nfs disk to guest.
start=`date`
UpdateSummary "Debug: start date is $start"
yum install nfs-utils -y
mkdir /nfs
mount $nfs /nfs
mount |grep $nfs
if [ ! "$?" -eq 0 ]; then
    LogMsg "Test Failed. nfs disk mount failed."
    UpdateSummary "Test failed.nfs disk mount failed."
    SetTestStateAborted
    exit 1
else
    LogMsg " nfs disk mount successfully."
    UpdateSummary "nfs disk mount successfully."
fi

#Copy a big file more then 5G to scsi type disk.
scp -i $HOME/.ssh/id_rsa_private -o StrictHostKeyChecking=no /nfs/bigfile root@${1}:/root
if [ ! "$?" -eq 0 ]; then
    LogMsg "Test Failed.  Copy bigfile File from guestA nfs to guestB SCSI disk Failed."
    UpdateSummary "Test failed.  Copy bigfile File from guestA nfs to guestB SCSI disk failed."
    SetTestStateFailed
    exit 1
else
    LogMsg "Copy bigfile File from guestA nfs to guestB SCSI disk successfully."
    UpdateSummary "Copy bigfile File from guestA nfs to guestB SCSI disk successfully."
fi

start=`date`
UpdateSummary "Debug: nfs end date scsi start date is $start"
#scp bigfile file to local scsi disk path from guest B.
scp -i $HOME/.ssh/id_rsa_private -o StrictHostKeyChecking=no root@${1}:/root/bigfile /root/
if [ ! "$?" -eq 0 ]; then
    LogMsg "Test Failed. Copy bigfile File from guestB scsi to guestA scsi disk Failed."
    UpdateSummary "Test failed.Copy bigfile File from guestB scsi to guestA scsi disk failed."
    SetTestStateFailed
    exit 1
else
    LogMsg " Copy bigfile File from guestB scsi to guestA scsi disk successfully."
    UpdateSummary "Copy bigfile File from guestB scsi to guestA scsi disk successfully."
fi

#add IDE disk to guest and make filesystem on it.
system_part=`df -h | grep /boot | awk 'NR==1' | awk '{print $1}'| grep a`

if [ ! $system_part ]; then
#   The IDE disk should be sda
    disk_name="sda"
else
#   The IDE disk should be sdb
    disk_name="sdb"
fi

LogMsg "disk_name is $disk_name"

# Do Partition for IDE disk.
fdisk /dev/"$disk_name" <<EOF
n
p
1


w
EOF

# Get new partition
kpartx /dev/"$disk_name"

# Wait a while
sleep 6

# Format ext4
mkfs.ext4 /dev/"$disk_name"1
if [ ! "$?" -eq 0 ]
then
    LogMsg "Format Failed"
    UpdateSummary "FAIL: Format Failed"
    SetTestStateAborted
    exit 1
else
    LogMsg "Format successfully"
    UpdateSummary "Passed: Format successfully"
fi

#Mount ide disk to /mnt.
mount /dev/"$disk_name"1 /mnt
if [ ! "$?" -eq 0 ]
then
    LogMsg "Mount Failed"
    UpdateSummary "FAIL: Mount Failed"
    SetTestStateAborted
    exit 1
else
    LogMsg "Mount ide disk successfully"
    UpdateSummary "Passed: Mount ide disk successfully"
fi

# copy file to ide disk type.
scp -i $HOME/.ssh/id_rsa_private -o StrictHostKeyChecking=no root@${1}:/root/bigfile /mnt
if [ ! "$?" -eq 0 ]
then
    LogMsg "copy file from guestB scsi to guestA ide disk Failed"
    UpdateSummary "FAIL: copy file from guestB scsi to guestA ide disk Failed"
    start=`date`
    UpdateSummary "Debug: IDE end date is $start"
    SetTestStateFailed
    exit 1
else
    LogMsg "Copy  File from guestB scsi to guestA ide disk successfully"
    UpdateSummary "FAIL: Copy  File from guestB scsi to guestA disk successfully"
    start=`date`
    UpdateSummary "Debug: IDE end date is $start"
    SetTestStateCompleted
    exit 0
fi
