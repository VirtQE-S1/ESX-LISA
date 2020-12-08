#!/bin/bash


########################################################################################
##	Description:
##		Unload vmware driver vmw_balloon for one hour.
##
##	Revision:
##		v1.0.0 - ldu - 03/30/2018 - Draft script for case ESX-OVT-009
##  	v1.0.1 - boyang - 05/15/2018 - Support all $DISTRO and multi modules
##  	v1.0.2 - boyang - 05/31/2019 - Incorrect VAR names
##  	v1.1.0 - boyang - 12/08/2020 - Support RHEL-9.0.0
########################################################################################


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


########################################################################################
# Main script body
########################################################################################
LogMsg "INFO: The Current OS: $DISTRO"
UpdateSummary "INFO: The Current OS: $DISTRO"

# Unload the driver vmw_balloon for an hour
current_time=`date +%s`
LogMsg "INFO: The Start Time: $current_time"
UpdateSummary "INFO: The Start Time: $current_time"

end_time=$[current_time+900]
LogMsg "DEBUG: end_time: $end_time"
UpdateSummary "DEBUG: end_time: $end_time"

# Get different $DISTROs moudles list. CURRENLTY. ONLY balloon is supported
modules_in_distro=`cat constants.sh | grep $DISTRO | awk -F "=" '{print $2}'`
LogMsg "DEBUG: modules_in_distro: $modules_in_distro"
UpdateSummary "DEBUG: modules_in_distro: $modules_in_distro"
if [ -z $modules_in_distro ]; then
    LogMsg "ERROR: Modules list is NULL"
    UpdateSummary "ERROR: Modules list is NULL"
    SetTestStateAborted
    exit 1
fi

# Convert list to modules arrary
modules_arr=$(echo $modules_in_distro | tr "," "\n")

# Modprobe and modprobe -r all modules an hour
while [ $current_time -lt $end_time ]
do
    # Modprobe and modprobe -r all modules in one cycle
    for m in $modules_arr
    do
        modprobe -r $m
        ret_remove=$?
        call_trace=`dmesg | grep "CallTrace" | wc -l`
        if [ $ret_remove -ne 0 -o $call_trace -ne 0 ]
        then
            SetTestStateFailed
            exit 1
        fi

	dmesg -c

        modprobe $m
        ret_add=$?
        call_trace=`dmesg | grep "CallTrace" | wc -l`
        if [ $ret_add -eq 1 -o $call_trace -ne 0 ]
        then
            SetTestStateFailed
            exit 1
        fi
    done

    current_time=`date +%s`

done

SetTestStateCompleted
exit 0
