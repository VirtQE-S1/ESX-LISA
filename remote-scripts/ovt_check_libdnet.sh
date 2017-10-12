#!/bin/bash

###############################################################################
##
## Description:
##   This script checks libdnet after installed open-vm-tools.
##   The libdnet should under list in open-vm-tools dependancy.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 07/19/2017 - Draft script for case ESX-OVT-010.
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

rpm -qR open-vm-tools |grep "libdnet"
if [[ $? == 0 ]]; then
    LogMsg "Test successfully. There's libdnet."
    UpdateSummary "Test successfully. There's libdnet."
    SetTestStateCompleted
    exit 0
else
    LogMsg "Test Failed. There's NO libdnet."
    UpdateSummary "Test failed. There's NO libdnet."
    SetTestStateFailed
    exit 1
fi
