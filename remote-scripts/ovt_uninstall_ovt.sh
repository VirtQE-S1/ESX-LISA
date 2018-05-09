#!/bin/bash

###############################################################################
##
## Description:
##   This script unintall the open-vm-tools.
##   The open-vm-tools should be uninstalled successfully.
##
###############################################################################
##
## Revision:
##  v1.0 - ldu - 03/07/2017 - Draft script for case ESX-OVT-003.
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

version=$(rpm -qa open-vm-tools)
LogMsg "$version"
if [ -n "$version" ]; then
        yum erase -y open-vm-tools-desktop
        yum erase -y open-vm-tools
        version=$(rpm -qa open-vm-tools)
        if [ -n "$version" ]; then
                LogMsg "Unistall the open-vm-tools Failed"
                UpdateSummary "Test Failed. Unistall the open-vm-tools Failed."
                SetTestStateFailed
                exit 1
        else
                LogMsg "Unistall the open-vm-tools"
                UpdateSummary "Test Successfully. Unistall the open-vm-tools."
                SetTestStateCompleted
                exit 0
        fi
else
        LogMsg "the open-vm-tools not installed"
        UpdateSummary "Test Failed. open-vm-tools not installed."
        SetTestStateAborted
        exit 1
fi
