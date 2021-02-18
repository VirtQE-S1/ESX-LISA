#!/bin/bash


########################################################################################
##	Description:
##		Check vmcore after kdump.
##
##	Revision:
##		v1.0.0 - boyang - 02/08/2021 - Build the script.
########################################################################################


# Source utils.sh
dos2unix utils.sh
. utils.sh || {
	echo "Error: unable to source utils.sh!"
	exit 1
}


# Source constants file and initialize most common variables
UtilsInit


########################################################################################
## Main Body
########################################################################################
vmcore_path="/var/crash/"
timeout=180


# Find out a vmcore after kdump and rebooting.
LogMsg "INFO: Will find  out a vmcore in ${timeout}."
UpdateSummary "INFO: Will find out a vmcore in ${timeout}."
while [[ $timeout -gt 0 ]];
do
	vmcore_find=`find $vmcore_path -name "vmcore" -type f -size +20M`
	LogMsg "DEBUG: vmcore_find: ${vmcore_find}."
	UpdateSummary "DEBUG: vmcore_find: ${vmcore_find}."
	if [[ -n $vmcore_find ]]; then
		LogMsg "INFO: Find a vmcore file after kdump."
		UpdateSummary "INFO: Find a vmcore file after kdump."
		SetTestStateCompleted	
		exit 0
	else
		LogMsg  "WARNING: Can't find a vmcore, try again in ${timeout}."
		UpdateSummary  "WARNING: Can't find a vmcore, try again in ${timeout}."			
	fi

	sleep 6
	timeout=$((timeout-6))
done


LogMsg "ERROR: Failed to  find a vmcore file at last."
UpdateSummary "ERROR: Failed to find a vmcore file at last."
SetTestStateFailed
exit 1
