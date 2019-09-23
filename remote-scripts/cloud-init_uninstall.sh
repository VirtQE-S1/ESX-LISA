#!/bin/bash

###############################################################################
##
## Description:
##   This script unintall the cloud-init.
##   The cloud-init should be uninstalled successfully.
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

version=$(rpm -qa cloud-init)
LogMsg "$version"
if [ -n "$version" ]; then
        yum erase -y cloud-init
        version=$(rpm -qa cloud-init)
        if [ -n "$version" ]; then
                LogMsg "Unistall the cloud-init Failed"
                UpdateSummary "Test Failed. Unistall the cloud-init Failed."
                SetTestStateFailed
                exit 1
        else
                LogMsg "Unistall the cloud-init"
                UpdateSummary "Test Successfully. Unistall the cloud-init."
                SetTestStateCompleted
                exit 0
        fi
else
        yum install -y cloud-init
        LogMsg "the cloud-init not installed, install it with yum"
        UpdateSummary "cloud-init not installed,so install it first."
fi

yum erase -y cloud-init
version=$(rpm -qa cloud-init)
if [ -n "$version" ]; then
        LogMsg "Unistall the cloud-init Failed"
        UpdateSummary "Test Failed. Unistall the cloud-init Failed."
        SetTestStateFailed
        exit 1
 else
        LogMsg "Unistall the cloud-init"
        UpdateSummary "Test Successfully. Unistall the cloud-init."
        SetTestStateCompleted
        exit 0
fi