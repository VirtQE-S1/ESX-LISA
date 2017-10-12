#!/bin/bash

###############################################################################
##
## Description:
##   This script checks the guest time could be sync with host after change the guest time behand host for a period time.
##   The guest time should be same with host after enable timesync.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 08/30/2017 - Draft script for case ESX-OVT-016.
##
###############################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
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

vmware-toolbox-cmd timesync enable
#enable the guest timesync with host
date -s "2008-08-08 12:00:00"

sleep 60
#wait 60seconds and check the guest time and host time difference

datehost=`vmware-toolbox-cmd stat hosttime`
timehost=`date +%s -d"$datehost"`
timeguest=`date +%s`

offset=$[timehost-timeguest]

if [ $offset -ne 0 ]; then
        LogMsg "Info : The guest time is sync with host failed."
        UpdateSummary "offset: $offset,Test Failed,The guest time is sync with host failed."
        SetTestStateFailed
        exit 1
else

        LogMsg "offset: $offset"
        UpdateSummary "offset: $offset,Test Successfully. The guest time is sync with host successfully."
        SetTestStateCompleted
        exit 0
fi
