#!/bin/bash

###############################################################################
##
## Description:
##   Test DPDK work or not by hello world script
##
###############################################################################
##
## Revision:
## v1.0 - Ruowen Qin - 7/5/2018 - Build the script
##
###############################################################################


: '
        <test>
            <testName>dpdk_helloworld</testName>
            <testID>ESX-DPDK-003</testID>
            <testScript>dpdk_helloworld_3.sh</testScript>
            <files>remote-scripts/dpdk_helloworld_3.sh</files>
            <files>remote-scripts/utils.sh</files>
            <RevertDefaultSnapshot>False</RevertDefaultSnapshot>
            <testParams>
                <param>TC_COVERED=RHEL-136158</param>
            </testParams>
            <timeout>240</timeout>
            <onError>Continue</onError>
            <noReboot>True</noReboot>
        </test>

'

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


# Printout current Guest OS
GetDistro
LogMsg $DISTRO
# This case cannot run on rhel6
if [ "$DISTRO" == "redhat_6" ]
then
    SetTestStateSkipped
    LogMsg "Not support rhel6"
    exit 1
fi


# Compile HelloWorld and run
cd $RTE_SDK/examples/helloworld || exit 1
make
output_lines=./build/helloworld | wc -l


# Check output
if [ ! "$?" -eq 0 -a output_lines -ne 0 ]
then
    LogMsg "Hello World Failed"
    SetTestStateFailed
    exit 1
else
    SetTestStateCompleted
    exit 0
fi
