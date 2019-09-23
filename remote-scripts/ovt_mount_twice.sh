#!/bin/bash

###############################################################################
##
## Description:
##   This script checks
##  Take snapshot after deadlock condiation.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 23/07/2017 - Take snapshot after deadlock condiation.
##
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

if [[ $DISTRO == "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi

yum -y install nfs-utils
#Create logical volume with new added disk_name
fdisk /dev/sdb <<EOF
n
p
1


w
EOF

#create first logical device
pvcreate /dev/sdb1
vgcreate vg01 /dev/sdb1
lvcreate -n lvdata01 -L 5GB vg01
mkfs.xfs /dev/vg01/lvdata01
mount /dev/vg01/lvdata01 /var
if [ ! "$?" -eq 0 ]
then
    LogMsg "ERROR: mount logical volume 01 failed"
    UpdateSummary "ERROR: mount logical volume 01 failed"
    SetTestStateAborted
    exit 1
else
    LogMsg "INFO: mount logical volume 01 successfully"
    UpdateSummary "INFO: mount logical volume 01 successfully"
fi

#setup one loop device
dd if=/dev/zero of=/var/test.img bs=1500 count=1M
losetup /dev/loop0 /var/test.img
pvcreate /dev/loop0
vgcreate vg02 /dev/loop0
lvcreate -n lvdata01 -L 1GB vg02
mkfs.xfs /dev/vg02/lvdata01
mkdir /var/myspace
mount /dev/vg02/lvdata01 /var/myspace
if [ ! "$?" -eq 0 ]
then
    LogMsg "ERROR: mount logical volume vg02 failed"
    UpdateSummary "ERROR: mount logical volume 02 failed"
    SetTestStateAborted
    exit 1
else
    LogMsg "INFO: mount logical volume 02 successfully"
    UpdateSummary "INFO: mount logical volume 02 successfully"
fi

#mount again lv01
mkdir /test
mount /dev/vg01/lvdata01 /test
if [ ! "$?" -eq 0 ]
then
    LogMsg "ERROR: mount again logical volume 01 failed"
    UpdateSummary "ERROR: mount again logical volume 01 failed"
    SetTestStateFailed
    exit 1
else
    LogMsg "INFO: mount again logical volume 01 successfully"
    UpdateSummary "INFO: mount again logical volume 01 successfully"
    SetTestStateCompleted
    exit 0
fi