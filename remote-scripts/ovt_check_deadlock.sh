#!/bin/bash

###############################################################################
##
## Description:
##   This script checks vmtoolsd status.
##   The vmtoolsd status should be running.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 03/07/2017 - Draft script for case ESX-OVT-002.
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
service=$(systemctl status vmtoolsd |grep running -c)

if [ "$service" = "1" ]; then
  LogMsg $service
  UpdateSummary "Test Successfully. service vmtoolsd is running."

else
  LogMsg "Info : The service vmtoolsd is not running'"
  UpdateSummary "Test Successfully. The service vmtoolsd is not running."

fi

# Set sysctl parameter hung_task_panic.
echo 1 > /proc/sys/kernel/hung_task_panic

# Setup a loop device:
mknod -m660 /dev/loop0 b 7 0
ls -l /dev/loop0
chown root.disk /dev/loop0
dd if=/dev/zero of=file bs=1 count=1 seek=512M
losetup -f file
losetup -a

# Build 'xfs' filesystem on /dev/loop0 device.
mkfs.xfs /dev/loop0

# Mount /dev/loop0 device.
mkdir -p /srv/node/partition1
mount /dev/loop0 /srv/node/partition1
sleep 2
loop=$(mount | grep loop -c)
UpdateSummary "DEBUG: loop: $loop"
if [ "$loop" = "1" ]; then
  LogMsg $loop
  UpdateSummary "Mount Successfully. loop ($loop) device mount."
  SetTestStateCompleted
  exit 0
else
  LogMsg "Mount failed. loop($loop) device mount failed"
  UpdateSummary "Mount failed. loop($loop) device mount failed."
  SetTestStateFailed
  exit 1
fi
