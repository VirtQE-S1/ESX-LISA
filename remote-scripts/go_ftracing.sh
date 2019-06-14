#!/bin/bash


###############################################################################
##
## Description:
##  check guest status when doing function tracing.
##
## Revision:
##  v1.0.0 - ldu - 04/10/2019 - Draft script for case ESX-GO-018
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


# mount ftracing
mount -t debugfs nodev /sys/lernel/debug

#Do function tracing
echo function > /sys/kernel/debug/tracing/current_tracer
if [[ $? == 0 ]]; then
    LogMsg "Test successfully. The function tracing works."
    UpdateSummary "Test successfully.The function tracing works."
else
    LogMsg "Test Failed. The function tracing not work ."
    UpdateSummary "Test failed. The function tracing not work."
    SetTestStateAborted
    exit 1
fi

#Check the ftrac log, make sure there is no vmware_sched_clock log.
cat /sys/kernel/debug/tracing/trace |grep vmware_sched_clock
if [[ $? == 0 ]]; then
    LogMsg "Test Failed. there is vmware_sched_clock log in ftrace "
    UpdateSummary "Test failed. there is vmware_sched_clock log in ftrace ."
    SetTestStateFailed
    exit 1
else
    LogMsg "Test successfully.there isn't vmware_sched_clock log in ftrace."
    UpdateSummary "Test successfully.there isn't vmware_sched_clock log in ftrace."
    SetTestStateCompleted
    exit 0
fi