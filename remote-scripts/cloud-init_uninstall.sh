#!/bin/bash


########################################################################################
## Description:
##  This script unintall the cloud-init.
##	The cloud-init should be uninstalled successfully.
##
## Revision:
##  v1.0.0 - ldu - 03/20/2019 - Draft script for case ESX-cloud-init-002.
##  v1.1.0 - boyang - 10/15/2019 - Check yum install or pass this case even it fails.
########################################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


# Skip RHEL6
if [[ $DISTRO == "redhat_6" ]]; then
        SetTestStateSkipped
        exit
fi


version=$(rpm -qa cloud-init)
LogMsg "DEBUG: version: $version"
if [ -n "$version" ]; then
        yum erase -y cloud-init
        version=$(rpm -qa cloud-init)
        if [ -n "$version" ]; then
                LogMsg "ERROR: Unistall the cloud-init Failed."
                UpdateSummary "ERROR: Unistall the cloud-init Failed."
                SetTestStateFailed
                exit 1
        else
                LogMsg "INFO: Unistall the cloud-init well."
                UpdateSummary "Unistall the cloud-init well."
                SetTestStateCompleted
                exit 0
        fi
else
        LogMsg "INFO: VM haven't cloud-init, install it firstly and re-test."
        UpdateSummary "INFO: VM haven't cloud-init, install it firstly and re-test."
        yum install -y cloud-init
        if [ $? -ne 0 ]; then
                LogMsg "ERROR: Yum install cloud-init failed."
                UpdateSummary "ERROR: Yum install cloud-init failed."
                SetTestStateFailed
                exit 1
        fi
fi


yum erase -y cloud-init
version=$(rpm -qa cloud-init)
if [ -n "$version" ]; then
        LogMsg "ERROR: Unistall the cloud-init Failed"
        UpdateSummary "ERROR: Unistall the cloud-init Failed."
        SetTestStateFailed
        exit 1
 else
        LogMsg "INFO: Unistall the cloud-init successfully."
        UpdateSummary "INFO: Unistall the cloud-init successfully."
        SetTestStateCompleted
        exit 0
fi
