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
## 		v1.3.0 - boyang - 11/30/2017 - Support RHEL-9.0.0 kdump service prepare.
########################################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
	echo "Error: unable to source utils.sh!"
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
			LogMsg "ERROR: Kdump isn't active after reboot"
			UpdateSummary "ERROR: kdump service isn't active after reboot"
			exit 1
		else
			LogMsg "INFO: kdump service is active after reboot"
			UpdateSummary "INFO: kdump service is active after reboot"
		fi
		;;
	redhat_7)
		systemctl status kdump | grep "Active: active (exited)"
		if  [ $? -eq 0 ]
		then
			LogMsg "INFO: kdump service is active after reboot"
			UpdateSummary "INFO: kdump service is active after reboot"
		else
			LogMsg "ERROR: Kdump isn't active after reboot"
			UpdateSummary "ERROR: kdump service isn't active after reboot"
			exit 1
		fi
		;;
	redhat_[8-9])
		systemctl status kdump | grep "Active: active (exited)"
		if  [ $? -eq 0 ]
		then
			LogMsg "INFO: kdump service is active after reboot"
			UpdateSummary "INFO: kdump service is active after reboot"
		else
			LogMsg "ERROR: Kdump isn't active after reboot"
			UpdateSummary "ERROR: kdump service isn't active after reboot"
			exit 1
		fi		
		;;
        *)
			LogMsg "ERROR: Unknown OS"
			UpdateSummary "ERROR: Unknown OS"
			exit 1
		;;
	esac
}


ConfigureNMI()
{
	sysctl -w kernel.unknown_nmi_panic=1
	if [ $? -ne 0 ]; then
		LogMsg "ERROR: Fail to enable kernel to call panic when it receives a NMI"
		UpdateSummary "ERROR: Fail to enable kernel to call panic when it receives a NMI"
		exit 1
    else
		LogMsg "INFO: Enabling kernel to call panic when it receives a NMI"
		UpdateSummary "INFO: Enabling kernel to call panic when it receives a NMI"
    fi
}

# Can't trigger kdump with NMI in Linux ENV. Put it here firstly
# ConfigureNMI

# Ensure kdump service status after parameters modification and reboot
# Maybe Check_Kdump_Running fails several times after booting, as kdump service is not ready 
# So Check_Kdump_Running will be executed by serveral times in while loop
Check_Kdump_Running

# Prepare for trigger kdump.
LogMsg "INFO: Prepare for kernel panic."
UpdateSummary "INFO: Prepare for kernel panic."
if [ -f $proc_sys_kernel_sysrq ]
then	
	echo 1 > $proc_sys_kernel_sysrq
	LogMsg "INFO: Now reboot VM to trigger kdump"
	UpdateSummary "INFO: Now reboot VM to trigger kdump"
else
	LogMsg "ERROR: $proc_sys_kernel_sysrq doesn't esxit, try again."
	UpdateSummary "ERROR: $proc_sys_kernel_sysrq doesn't esxit, try again"
	exit 1
fi
