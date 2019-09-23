#!/bin/bash

###############################################################################
##
## Description:
##   This script install the cloud-init.
##   The cloud-init should be installed, just for gating test.
##
###############################################################################
##
## Revision:
##  v1.0 - ldu - 04/09/2019 - Draft script for case ESX-cloud-init-003.
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


version=$(rpm -qa cloud-init)
LogMsg "INFO: Cloud-init version is $version"
UpdateSummary "INFO: Cloud-init version is $version"
if [ -n "$version" ]; then
        LogMsg "cloud-init installed successfully."
        UpdateSummary " cloud-init installed successfully."
        SetTestStateCompleted
        exit 0
else
        LogMsg "The cloud-init not install when guest install"
        UpdateSummary "Test Failed. The cloud-init not install."

        yum install -y cloud-init
        version=$(rpm -qa cloud-init)
        LogMsg "INFO: Cloud-init version is $version"
        UpdateSummary "INFO: Cloud-init version is $version"
        if [ -n "$version" ]; then
            LogMsg "cloud-init installed successfully."
            UpdateSummary " cloud-init installed successfully."
            SetTestStateCompleted
            exit 0
        else
            LogMsg "ERROR: After new install, still failed"
            UpdateSummary "ERROR: After new install, still failed"
            SetTestStateFailed
            exit 1
        fi
fi
