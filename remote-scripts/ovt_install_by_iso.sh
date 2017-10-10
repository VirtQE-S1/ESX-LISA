#!/bin/bash

###############################################################################
##
## Description:
##   This script checksinstalled open-vm-tools by iso installed RHEL7.
##   The guest should installed open-vm-tools.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 09/01/2017 - Draft script for case ESX-OVT-018.
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

#The test guest is installed by iso, so after start the guest, check the open-vm-tools by rpm command.
rpm -qa open-vm-tools
if [[ $? == 0 ]]; then
    LogMsg "Test successfully. The open-vm-tools installed."
    UpdateSummary "Test successfully. The open-vm-tools installed."
    SetTestStateCompleted
    exit
else
    LogMsg "Test Failed. The open-vm-tools not installed."
    UpdateSummary "Test failed. The open-vm-tools not installed."
    SetTestStateFailed
    exit 1
fi
