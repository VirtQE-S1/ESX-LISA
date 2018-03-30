#!/bin/bash

###############################################################################
##
## Description:
##   This script test unload vmware driver vmw_balloon for one hour.
##   RHEL7-50863

# <test>
#     <testName>go_unload_vmw_modules</testName>
#     <testID>ESX-OVT-00</testID>
#     <testScript>go_unload_vmw_modules.sh</testScript>
#     <files>remote-scripts/go_unload_vmw_modules.sh</files>
#     <files>remote-scripts/utils.sh</files>
#     <testParams>
#         <param>TC_COVERED=RHEL6-34877,RHEL7-50863</param>
#     </testParams>
#     <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
#     <timeout>6200</timeout>
#     <onError>Continue</onError>
#     <noReboot>False</noReboot>
# </test>
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 03/30/2018 - Draft script for case ESX-OVT-009.
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

#unload the driver vmw_balloon for an hour.
current_time=`date +%H%M`
UpdateSummary "the start time is $current_time."
end_time=$[current_time+60]
if [[ $DISTRO = "redhat_6" ]];
then
    UpdateSummary "the current OS is $DISTRO."
    while [ $current_time -lt $end_time ]
    do
        modprobe -r vmware_balloon
        modprobe vmware_balloon
        current_time=`date +%H%M`

    done
else
    UpdateSummary "the current OS is $DISTRO."
    while [ $current_time -lt $end_time ]
    do
        modprobe -r vmw_balloon
        modprobe vmw_balloon
        current_time=`date +%H%M`
    done

fi
#Check the times.
if [ $current_time -eq $end_time ]; then
    LogMsg "Test successfully. The current time $current_time equal with end time $end_time."
    UpdateSummary "Test successfully.The current time $current_time equal with end time $end_time."
    SetTestStateCompleted
    exit 0
else
    LogMsg "Test Failed.The current time $current_time not equal with end time $end_time."
    UpdateSummary "Test failed. The current time $current_time not equal with end time $end_time."
    SetTestStateFailed
    exit 1
fi
