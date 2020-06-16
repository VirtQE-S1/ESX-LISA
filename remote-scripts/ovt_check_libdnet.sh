#!/bin/bash


########################################################################################
## Description:
##   This script checks libdnet after installed open-vm-tools.
##
## Revision:
## 	v1.0.0 - ldu - 07/19/2017 - Draft script for case ESX-OVT-010.
## 	v1.1.0 - boyang - 12/10/2019 - Fix incorrect syntax of "-o".
########################################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


########################################################################################
## Main Body
########################################################################################
if [ $DISTRO == "redhat_6" -o $DISTRO == "redhat_8" ]; then
    LogMsg "INFO: Skip the test in $DISTRO."
    UpdateSummary "INFO: Skip the test in $DISTRO."
    SetTestStateSkipped
    exit
fi


rpm -qR open-vm-tools | grep "libdnet"
if [[ $? == 0 ]]; then
    LogMsg "INFO: Test successfully. Found libdnet."
    UpdateSummary "INFO: Test successfully. Found libdnet."
    SetTestStateCompleted
    exit 0
else
    LogMsg "ERROR: Test Failed. There's NO libdnet."
    UpdateSummary "ERROR: Test failed. There's NO libdnet."
    SetTestStateFailed
    exit 1
fi
