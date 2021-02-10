#!/bin/bash


########################################################################################
##	Description:
##		Confirm kdump service running and echo 1 > /proc/sys/kernel/sysrq
##		Kdump service running and sysrq value is 1
##
##	Revision:
##		v1.0.0 - boyang - 01/18/2017 - Build the script.
##		v1.1.0 - boyang - 06/29/2017 - Setup kdump_trigger_service as a service.
## 		v1.2.0 - boyang - 10/13/2017 - Remove kdump_trigger_service as a service.
## 		v1.3.0 - boyang - 11/30/2020 - Support RHEL-9.0.0 kdump service prepare.
########################################################################################


# Source utils.sh.
dos2unix utils.sh
. utils.sh || {
	echo "Error: unable to source utils.sh."
	exit 1
}


# Source constants file and initialize most common variables
UtilsInit


########################################################################################
## Main Body
########################################################################################
proc_sys_kernel_sysrq="/proc/sys/kernel/sysrq"


Check_Kdump_Running(){
	case $DISTRO in
	redhat_6)
		service kdump status | grep "not operational"
		if  [ $? -eq 0 ]
		then
			LogMsg "ERROR: Kdump isn't active after reboot."
			UpdateSummary "ERROR: kdump service isn't active after reboot."
			SetTestStateFailed
			exit 1
		else
			LogMsg "INFO: kdump service is active after reboot."
			UpdateSummary "INFO: kdump service is active after reboot."
		fi
		;;
	redhat_[7-9])
		systemctl status kdump | grep "Active: active (exited)"
		if  [ $? -eq 0 ]
		then
			LogMsg "INFO: kdump service is active after reboot."
			UpdateSummary "INFO: kdump service is active after reboot."
		else
			LogMsg "ERROR: Kdump isn't active after reboot."
			UpdateSummary "ERROR: kdump service isn't active after reboot."
			SetTestStateFailed
			exit 1
		fi		
		;;
        *)
			LogMsg "ERROR: Unknown OS."
			UpdateSummary "ERROR: Unknown OS."
			SetTestStateFailed
			exit 1
		;;
	esac
}


# Ensure kdump service status after parameters modification and reboot.
# Maybe Check_Kdump_Running fails several times after booting, as kdump service is not ready.
# So Check_Kdump_Running will be executed by serveral times in while loop.
Check_Kdump_Running


# Prepare for trigger kdump.
LogMsg "INFO: Prepare for kernel panic."
UpdateSummary "INFO: Prepare for kernel panic."
if [ -f $proc_sys_kernel_sysrq ]
then	
	echo 1 > $proc_sys_kernel_sysrq
	SetTestStateCompleted
	exit 0
else
	LogMsg "ERROR: $proc_sys_kernel_sysrq doesn't esxit. Still try to trigger the kdump in the next step."
	UpdateSummary "ERROR: $proc_sys_kernel_sysrq doesn't esxit. Still try to triger the kdump in the next step."
	SetTestStateFailed
	exit 1
fi

