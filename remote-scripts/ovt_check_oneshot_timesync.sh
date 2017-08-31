#!/bin/bash

###############################################################################
##
## Description:
##   This script checks the guest time could be sync with host.
##   The guest time should be same with host after enable timesync.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 08/29/2017 - Draft script for case ESX-OVT-017.
##
###############################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

#. constants.sh || {
#    echo "Error: unable to source constants.sh!"
#    exit 1
#}


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
sync

vmware-toolbox-cmd timesync disable

# set new time for guest
date -s "2017-08-29 12:00:00"

#stanversion='open-vm-tools-10.1.5-2.el7.x86_64'
datehost=`vmware-toolbox-cmd stat hosttime`
timehost=`date +%s -d"$datehost"`
UpdateSummary "timehost  after disable: $timehost"
timeguest=`date +%s`
UpdateSummary "timeguest  after disable: $timeguest"

offset=$[timehost-timeguest]
UpdateSummary "offset: $offset."
if [ "$offset" -eq 0 ]; then
        LogMsg "Info :Set the guest time behand the host time failed"
        UpdateSummary "offset: $offset,Set the guest time behand the host time failed ."
        SetTestStateAborted
        exit 1
else
        LogMsg $offset
        UpdateSummary "offset: $offset,Set the guest time behand the host time successfully."
        vmware-toolbox-cmd timesync enable
        #enable the guest timesync with host
        datehost=`vmware-toolbox-cmd stat hosttime`
        timehost=`date +%s -d"$datehost"`
        UpdateSummary "timehost  after enable: $timehost"
        timeguest=`date +%s`
        UpdateSummary "timeguest  after enable: $timeguest"
        offset=$[timehost-timeguest]
        #calculate the guest time and host time difference
        if [ $offset -ne 0 ]; then
                LogMsg "Info : The guest time is sync with host failed."
                UpdateSummary "offset: $offset,offset Test Failed,The guest time is sync with host failed."
                SetTestStateFailed
                exit 1
        else
                LogMsg "$offset"
                UpdateSummary "offset: $offset,Test Successfully. The guest time is sync with host successfully."
                SetTestStateCompleted
                exit 1
        fi

fi
