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
###############################################################################



# This will bind second and thrid network adapter to DPDK
source /etc/profile.d/dpdk.sh

    if [ ! "$?" -eq 0 ]
    then
        LogMsg "Source Code Download Failed"
        SetTestStateAborted
    fi

cd "$RTE_SDK" || exit 1
$RTE_SDK/usertools/dpdk-devbind.py -s
modprobe uio_pci_generic
insmod "$RTE_SDK/$RTE_TARGET/kmod/igb_uio.ko"

Server_IP=$(echo "$SSH_CONNECTION"| awk '{print $3}')

LogMsg "$Server_IP"

Server_Adapter=$(ip a|grep "$Server_IP"| awk '{print $(NF)}')


if [ "$(./usertools/dpdk-devbind.py -s | grep unused=igb_uio | wc -l)"  -gt 3 ];
then
    count=0
    for i in $(./usertools/dpdk-devbind.py -s | grep unused=igb_uio | awk 'NR>0{print}'\
        |  awk 'BEGIN{FS="="}{print $2}' | awk '{print $1}');
    do
        if [ "$i" != "$Server_Adapter" ];
        then
            LogMsg "Will Disconnect $i"
            nmcli device disconnect "$i"
            count=$((count + 1))

            LogMsg "Start Bind $i"
            ./usertools/dpdk-devbind.py -b igb_uio "$i"
            if [ $count -eq 2 ]; then
                break
            fi
        fi
    done
else
    LogMsg "Failed Not Enough Netowrk Adapter"
    SetTestStateAborted
fi

if [ "$(./usertools/dpdk-devbind.py -s | grep drv=igb_uio | wc -l)" -eq 2 ];
then
    LogMsg "Successfully bind two network adapter to DPDK igb_uio"
        UpdateSummary "Successfully bind two network adapter to DPDK igb_uio"
    SetTestStateCompleted
else
    LogMsg "Failed to bind two network adapter to DPDK igb_uio"
        UpdateSummary "Failed to bind two network adapter to DPDK igb_uio"
    SetTestStateFailed
fi