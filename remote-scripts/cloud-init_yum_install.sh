#!/bin/bash

###############################################################################
##
## Description:
##   This script install the cloud-init.
##   The cloud-init should be installed with yum command successfully.
##
###############################################################################
##
## Revision:
##  v1.0 - ldu - 03/20/2019 - Draft script for case ESX-cloud-init-002.
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

yum erase -y cloud-init
version=$(rpm -qa cloud-init)
LogMsg "$version"
if [ -n "$version" ]; then
        LogMsg "unintall the cloud-init Failed"
        UpdateSummary "Test Failed. unintall the cloud-init Failed."
        SetTestStateAborted
        exit 1
else
        yum -y install cloud-init
        version=$(rpm -qa cloud-init)
        if [ -n "$version" ]; then
                LogMsg "cloud-init installed successfully."
                UpdateSummary " cloud-init installed successfully."
                SetTestStateCompleted
                exit 0
        else
                LogMsg "cloud-init installed Failed."
                UpdateSummary " cloud-init installed Failed."
                SetTestStateFailed
                exit 1
        fi
fi
