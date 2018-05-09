#!/bin/bash

###############################################################################
##
## Description:
##   This script checks the guest time could be sync with host after restart vmtoolsd service.
##   The guest time should be same with host after restart vmtoolsd service.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 08/29/2017 - Draft script for case ESX-OVT-020.
## RHEL7-57926
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
if [[ $DISTRO == "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi


# set new time for guest
date -s "2017-08-29 12:00:00"

#Get the host time and guest time, print the seconds from 1970-01-01 to now.
datehost=`vmware-toolbox-cmd stat hosttime`
timehost=`date +%s -d"$datehost"`
UpdateSummary "timehost  after disable: $timehost"
timeguest=`date +%s`
UpdateSummary "timeguest  after disable: $timeguest"
#compare the time difference between guest and host.
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

        #Restart the vmtoolsd service, the guest time should be sync with host.
        systemctl restart vmtoolsd
        sleep 6
        #Get the host time and guest time, print the seconds from 1970-01-01 to now.
        datehost=`vmware-toolbox-cmd stat hosttime`
        timehost=`date +%s -d"$datehost"`
        UpdateSummary "timehost  after enable: $timehost"
        timeguest=`date +%s`
        UpdateSummary "timeguest  after enable: $timeguest"

        #calculate the guest time and host time difference
        offset=$[timehost-timeguest]

        if [ $offset -ne 0 ]; then
                LogMsg "Info : The guest time is sync with host failed."
                UpdateSummary "offset: $offset,offset Test Failed,The guest time is sync with host failed."
                SetTestStateFailed
                exit 1
        else
                LogMsg "$offset"
                UpdateSummary "offset: $offset,Test Successfully. The guest time is sync with host successfully."
                SetTestStateCompleted
                exit 0
        fi

fi
