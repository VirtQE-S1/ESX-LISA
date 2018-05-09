#!/bin/bash

###############################################################################
##
## Description:
##   This script checks vgauth files under /usr/lib/ after installed open-vm-tools.
##   The files VGAuthService and vmware-vguath-cmd should be under /usr/lib.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 08/29/2017 - Draft script for case ESX-OVT-013.
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

cat /usr/bin/VGAuthService
if [[ $? == 0 ]]; then
    cat /usr/bin/vmware-vgauth-cmd
    if [[ $? == 0 ]]; then
        LogMsg "Test successfully. There's vmware-vguath-cmd and VGAuthService."
        UpdateSummary "Test successfully. There's VGAuthService and vmware-vguath-cmd."
        SetTestStateCompleted
        exit 0
    else
        LogMsg "Test Failed. There's NO  vmware-vguath-cmd."
        UpdateSummary "Test failed. There's NO  vmware-vguath-cmd."
        SetTestStateFailed
        exit 1
    fi
else
    LogMsg "Test Failed. There's NO VGAuthService."
    UpdateSummary "Test failed. There's NO VGAuthService."
    SetTestStateFailed
    exit 1
fi
