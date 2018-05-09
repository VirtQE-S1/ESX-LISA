#!/bin/bash

###############################################################################
##
## Description:
##   This script checks mount.vmhgfs not installed after install open-vm-tools.
##   There should not be contained mount.vmhgfs under /usr/sbin/.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 03/14/2017 - Draft script for case ESX-OVT-006.
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

cat /usr/sbin/mount.vmhgfs
if [[ $? == 0 ]]; then
    LogMsg "Test Failed. There's mount.vmhgfs file under /usr/sbin/."
    UpdateSummary "Test Failed. There's mount.vmhgfs file under /usr/sbin/."
    SetTestStateFailed
    exit 1
else
    LogMsg "Test Successfully. There's NO mount.vmhgfs file under /usr/sbin/."
    UpdateSummary "Test Successfully. There's NO mount.vmhgfs file under /usr/sbin/."
    SetTestStateCompleted
    exit 0
fi
