#!/bin/bash


###############################################################################
##
## Description:
##  check guest status when run cpupower frequency-info.
##
## Revision:
##  v1.0.0 - ldu - 06/14/2019 - Draft script for case ESX-GO-020
##  
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


# Install kernel-tools 
yum install -y kernel-tools

#check kernel-tools installed 
kernel_ver=$(rpm -qa kernel-tools)
LogMsg "DEBUG: ovt_ver: $kernel_ver"
UpdateSummary "DEBUG: ovt_ver: $kernel_ver"
if [ -z $kernel_ver ]; then
    LogMsg "ERROR: The kernel-tools is not installed"
    UpdateSummary "ERROR: Test Failed,kernel-tools is not installed"
    SetTestStateAborted
    exit 1
fi

#check the command
cpupower frequency-info
if [[ $? == 0 ]]; then
    LogMsg "Test successfully. The cpupower frequency-info works."
    UpdateSummary "Test successfully.Thecpupower frequency-info works."
    SetTestStateCompleted
    exit 0
else
    LogMsg "Test Failed. The cpupower frequency-info not work ."
    UpdateSummary "Test failed. The cpupower frequency-info not work."
    SetTestStateFailed
    exit 1
fi
