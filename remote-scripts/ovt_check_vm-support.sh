#!/bin/bash

###############################################################################
##
## Description:
##   This script checks vm-support path after installed open-vm-tools.
##   The vm-support should under /usr/bin/.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 03/16/2017 - Draft script for case ESX-OVT-009.
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

rpm -ql open-vm-tools |grep "/usr/bin/vm-support"
if [[ $? == 0 ]]; then
    LogMsg "Test successfully. There's vm-support file under /usr/bin/."
    UpdateSummary "Test successfully. There's vm-support file under /usr/bin/."
    SetTestStateCompleted
    exit 0
else
    LogMsg "Test Failed. There's NO vm-support file under /usr/bin/."
    UpdateSummary "Test failed. There's NO vm-support file under /usr/bin/."
    SetTestStateFailed
    exit 1
fi
