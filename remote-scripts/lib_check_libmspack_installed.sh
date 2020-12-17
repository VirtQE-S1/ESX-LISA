#!/bin/bash


########################################################################################
##	Description:
##		This script checks libmspack installed after install open-vm-tools.
##
##	Revision:
##		v1.0.0 - ldu - 03/14/2017 - Draft script for case ESX-OVT-007.
########################################################################################


# Source utils.sh
dos2unix utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


########################################################################################
## Main
########################################################################################
if [[ $DISTRO == "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi

rpm -qa libmspack
if [[ $? == 0 ]]; then
    LogMsg "INFO: Test successfully, libmspack installed."
    UpdateSummary "Test successfully, libmspack installed."
    SetTestStateCompleted
    exit 0
else
    LogMsg "ERROR: Test failed, libmspack is not installed."
    UpdateSummary "Test failed, libmspack is not installed."
    SetTestStateFailed
    exit 1
fi
