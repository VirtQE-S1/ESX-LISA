#!/bin/bash

###############################################################################
##
## Description:
##   This script install the open-vm-tools.
##   The open-vm-tools should be installed with yum command successfully.
##
###############################################################################
##
## Revision:
##  v1.0 - ldu - 03/14/2017 - Draft script for case ESX-OVT-005.
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

yum erase -y open-vm-tools-desktop
yum erase -y open-vm-tools
version=$(rpm -qa open-vm-tools)
LogMsg "$version"
if [ -n "$version" ]; then
        LogMsg "unintall the open-vm-tools Failed"
        UpdateSummary "Test Failed. unintall the open-vm-tools Failed."
        SetTestStateAborted
        exit 1
else
        yum -y install open-vm-tools-desktop
        version=$(rpm -qa open-vm-tools)
        if [ -n "$version" ]; then
                LogMsg "open-vm-tools installed successfully."
                UpdateSummary " open-vm-tools installed successfully."
                SetTestStateCompleted
                exit 0
        else
                LogMsg "open-vm-tools installed Failed."
                UpdateSummary " open-vm-tools installed Failed."
                SetTestStateFailed
                exit 1
        fi
fi
