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


# Prepare Start KNI

source /etc/profile.d/dpdk.sh
insmod "$RTE_SDK/$RTE_TARGET/kmod/rte_kni.ko"
cd "$RTE_SDK/examples/kni" || return
make
if [ ! "$?" -eq 0 ]
then
    LogMsg "KNI compile Failed"
    SetTestStateAborted
fi
cd build || return

# Start Connect with kernel

nohup ./kni -l 1-3 -n 4 -- -P -p 0x1 --config="(0,1,2)" &

if [ ! "$?" -eq 0 ]
then
    LogMsg "KNI start Failed"
    SetTestStateFailed
fi

systemctl restart NetworkManager
nmcli con add con-name vEth0 ifname vEth0 type Ethernet

if [ ! "$?" -eq 0 ]
then
    LogMsg "KNI connection Failed"
    SetTestStateFailed
fi
systemctl restart NetworkManager

# Test New Network Adapter
sleep 5

ping -I vEth0 -c 3 10.73.196.97
ping -I vEth0 -c 3 10.73.196.97 | grep ttl > /dev/null

status=$?
 
# Close KNI
if [ "$status" -eq 0 ]
then
    LogMsg "KNI is working"
    UpdateSummary "KNI is working"
    sleep 1
    LogMsg "Start to Close KNI"
    ps aux | grep "./kni -l 1-3 -n 4 -- -P -p 0x1" | grep -v grep | awk '{print $2}' | xargs kill
    SetTestStateCompleted
else
    LogMsg "KNI is not working"
    UpdateSummary "KNI is not working"
    SetTestStateFailed
fi
