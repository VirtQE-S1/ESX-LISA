#!/bin/bash

###############################################################################
##
## Description:
##   This script checks file open-vm-tools version.
##   The open-vm-tools version shoulb be open-vm-tools-10.1.5.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 03/07/2017 - Draft script for case ESX-OVT-001.
##
##
###############################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

. constants.sh || {
    echo "Error: unable to source constants.sh!"
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

#stanversion='open-vm-tools-10.1.5-2.el7.x86_64'
version=$(rpm -qa open-vm-tools)

if [ -n $version ]; then
        LogMsg $version
        UpdateSummary "open-vm-tools is installed ."
else
        LogMsg "Info : The open-vm-tools is not installed'"
        UpdateSummary "Test Failed,open-vm-tools is not installed ."
        SetTestStateFailed
fi

if [ "$version" = "$stanversion" ]; then
        LogMsg "$version"
        UpdateSummary "Test Successfully. The open-vm-tools version is right."
        SetTestStateCompleted
else
        LogMsg "Info : The build info not right'"
        UpdateSummary "Test Failed,open-vm-tools build info not right ."
        SetTestStateFailed
fi
