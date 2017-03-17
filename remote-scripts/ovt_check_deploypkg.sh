#!/bin/bash

###############################################################################
##
## Description:
##   This script checks deploypkg exist after installed open-vm-tools.
##   There should be contained libdeployPkgPlugin.so under /usr/lib64/open-vm-tools/plugins/vmsvc.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 03/15/2017 - Draft script for case ESX-OVT-008.
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

cat /usr/lib64/open-vm-tools/plugins/vmsvc/libdeployPkgPlugin.so
if [[ $? == 0 ]]; then
    LogMsg "Test successfully. There's libdeployPkgPlugin.so file under /usr/sbin/."
    UpdateSummary "Test successfully. There's libdeployPkgPlugin.so file under /usr/sbin/."
    SetTestStateCompleted
    exit
else
    LogMsg "Test Failed. There's NO libdeployPkgPlugin.so file under /usr/sbin/."
    UpdateSummary "Test failed. There's NO libdeployPkgPlugin.so file under /usr/sbin/."
    SetTestStateFailed
    exit 1
fi
