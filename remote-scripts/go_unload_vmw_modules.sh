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
current_time=`date +%s`
UpdateSummary "the start time is $current_time."
end_time=$[current_time+3600]
#check the OS Version.
if [[ $DISTRO = "redhat_6" ]];
then
    UpdateSummary "the current OS is $DISTRO."
    while [ $current_time -lt $end_time ]
    do
        modprobe -r vmware_balloon
         remove=$?
        call_trace=`dmesg |grep "CallTrace"|wc -l`
        if [ $remove -eq 1 -o $call_trace -ne 0 ]
        then
            SetTestStateFailed
            exit 1
        fi
        modprobe vmware_balloon
        add=$?
        call_trace=`dmesg |grep "CallTrace" |wc -l`
        if [ $add -eq 1 -o $call_trace -ne 0 ]
        then
            SetTestStateFailed
            exit 1
        fi
        current_time=`date +%s`
    done
else
    UpdateSummary "the current OS is $DISTRO."
    while [ $current_time -lt $end_time ]
    do
        modprobe -r vmw_balloon
        remove=$?
        call_trace=`dmesg |grep "CallTrace" |wc -l`
        if [ $remove -eq 1 -o $call_trace -ne 0 ]
        then
            SetTestStateFailed
            exit 1
        fi
        modprobe vmw_balloon
        add=$?
        call_trace=`dmesg |grep "CallTrace"|wc -l`
        if [ $add -eq 1 -o $call_trace -ne 0 ]
        then
            SetTestStateFailed
            exit 1
        fi
        current_time=`date +%s`
    done

fi
    SetTestStateCompleted
