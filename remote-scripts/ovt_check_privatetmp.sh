#!/bin/bash

###############################################################################
##
## Description:
##   This script checks privatetmp in systemd service files after installed open-vm-tools.
##   The PrivateTmp=true in vmtoolsd.service files.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 07/20/2017 - Draft script for case ESX-OVT-011.
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

if [[ $DISTRO != "redhat_7" ]]; then
    SetTestStateSkipped
    exit
fi

cat /usr/lib/systemd/system/vmtoolsd.service |grep "PrivateTmp=true"
if [[ $? == 0 ]]; then
    LogMsg "Test successfully. PrivateTmp=true in vmtoolsd.service files."
    UpdateSummary "Test successfully. PrivateTmp=true in vmtoolsd.service files."
    SetTestStateCompleted
    exit
else
    LogMsg "Test Failed. PrivateTmp=true not in vmtoolsd.service files."
    UpdateSummary "Test failed. PrivateTmp=true not in vmtoolsd.service files."
    SetTestStateFailed
    exit 1
fi
