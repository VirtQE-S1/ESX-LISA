#!/bin/bash

###############################################################################
##
## Description:
##   What does this script?
##   What's the result the case expected?
##
###############################################################################
##
## Revision:
## v1.0 - xiaofwan - 1/6/2017 - Draft shell script as test script.
##
###############################################################################

dos2unix utils.sh

#
# Source utils.sh
#
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

#
# Source constants file and initialize most common variables
#
UtilsInit

###############################################################################
##
## Put your test script here
## NOTES:
## 1. Please use LogMsg to output log to terminal.
## 2. Please use UpdateSummary to output log to summary.log file.
## 3. Please use SetTestStateFailed, SetTestStateAborted, SetTestStateCompleted,
##    and SetTestStateRunning to mark test status.
##
##################################################
SetTestStateFailed

GetDistro

if [ "$DISTRO" == "redhat_6" ]
then
    SetTestStateAborted
    LogMsg "Not support rhel6"
    exit 1
fi


cd $RTE_SDK/examples/helloworld || exit 1
make
./build/helloworld

if [ ! "$?" -eq 0 ]
then
    LogMsg "Hello World Failed"
    SetTestStateFailed
    exit 1
else
    SetTestStateCompleted
    exit 0
fi
