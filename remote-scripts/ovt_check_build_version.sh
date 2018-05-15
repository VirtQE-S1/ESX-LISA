#!/bin/bash


###############################################################################
##
## Description:
##  Checks file open-vm-tools version
##
## Revision:
##  v1.0.0 - ldu - 03/07/2017 - Draft script for case ESX-OVT-001
##  V1.0.1 - boyang - 05/15/2017 - Supports all distros
##
###############################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants.sh to get all paramters from XML <testParams>
. constants.sh || {
    echo "Error: unable to source constants.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


#######################################################################
#
# Main script body
#
#######################################################################


# If current Guest is supported in the XML <testParams>
# "cat constant.sh | grep $DISTRO" will get the standard OVT version of $DISTRO
distro_standard_version=`cat constants.sh | grep $DISTRO | awk -F "=" '{print $2}'`
LogMsg "DEBUG: distro_standard_version: $distro_standard_version"
UpdateSummary "DEBUG: distro_standard_version: $distro_standard_version"
if [ -z $distro_standard_version ]; then
    LogMsg "ERROR: Current Guest DISTRO isn't supported, UPDATE XML for this DISTRO"
    UpdateSummary "ERROR: Current Guest DISTRO isn't supported, UPDATE XML for this DISTRO"
    SetTestStateAborted
    exit 1
fi


# Known: Red Hat Enterprise Linux Server Release 6.X doesn't have OVT, it is VT
if [ $distro_standard_version == "NOOVT" ]; then
    LogMsg "WARNING: Current Guest $DISTRO doesn't have OVT, will skip it"
    UpdateSummary "WARNING: Current Guest $DISTRO doesn't have OVT, will skip it"
    SetTestStateSkipped
    exit 0
fi


# Get current Guest OVT version, it should == standard OVT version of $DISTRO
ovt_ver=$(rpm -qa open-vm-tools)
LogMsg "DEBUG: ovt_ver: $ovt_ver"
UpdateSummary "DEBUG: ovt_ver: $ovt_ver"
if [ -z $ovt_ver ]; then
    LogMsg "ERROR: The open-vm-tools is not installed"
    UpdateSummary "ERROR: Test Failed,open-vm-tools is not installed"
    SetTestStateAborted
    exit 1
fi


# Checkpoint, current Guest OVT version should be equal to standard OVT version
if [ "$ovt_ver" == "$distro_standard_version" ]; then
    LogMsg "PASS: The open-vm-tools version is correct"
    UpdateSummary "PASS: The open-vm-tools version is correct"
    SetTestStateCompleted
    exit 0
else
    LogMsg "FAIL: The open-vm-tools version is incorrect"
    UpdateSummary "FAIL: The open-vm-tools version is incorrect"
    SetTestStateFailed
    exit 1
fi
