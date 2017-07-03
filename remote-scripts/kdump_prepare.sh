#!/bin/bash

###############################################################################
##
## Description:
##   Confirm kdump service running and echo 1 > /proc/sys/kernel/sysrq
##   Kdump service running and sysrq value is 1
##
###############################################################################
##
## Revision:
## v1.0 - boyang - 18/01/2017 - Build script.
## v1.1 - boyang - 06/29/2017 - Setup kdump_trigger_service under /etc/init.d
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
## Main Body
##
###############################################################################

proc_sys_kernel_sysrq="/proc/sys/kernel/sysrq"

Check_Kdump_Running(){
	case $DISTRO in
	redhat_6)
		service kdump status | grep "not operational"
		if  [ $? -eq 0 ]
		then
			LogMsg "FAIL: Kdump isn't active after reboot."
			UpdateSummary "FAIL: kdump service isn't active after reboot."
			exit 1
		else
			LogMsg "PASS: kdump service is active after reboot!"
			UpdateSummary "PASS: kdump service is active after reboot!"
		fi
		;;
	redhat_7)
		service kdump status | grep "Active: active (exited)"
		if  [ $? -eq 0 ]
		then
			LogMsg "PASS: kdump service is active after reboot!"
			UpdateSummary "PASS: kdump service is active after reboot!"
		else
			LogMsg "FAIL: Kdump isn't active after reboot."
			UpdateSummary "FAIL: kdump service isn't active after reboot."
			exit 1
		fi
		;;
        *)
			LogMsg "FAIL: Unknown OS!"
			UpdateSummary "FAIL: Unknown OS!"
			exit 1
		;;
	esac
}

ConfigureNMI()
{
	sysctl -w kernel.unknown_nmi_panic=1
	if [ $? -ne 0 ]; then
		LogMsg "FAIL: Fail to enable kernel to call panic when it receives a NMI."
		UpdateSummary "FAIL: Fail to enable kernel to call panic when it receives a NMI."
		exit 1
    else
		LogMsg "PASS: Enabling kernel to call panic when it receives a NMI."
		UpdateSummary "PASS: Enabling kernel to call panic when it receives a NMI."
    fi
}

#######################################################################
#
# Main script body
#
#######################################################################

# As NMI, can't triggered in Linux ENV. Will put it here firstly
# ConfigureNMI

# Ensure kdump service status after reboot and parameters modification
Check_Kdump_Running

# Setup kdump_trigger service under /etc/init.d
cp /root/kdump_trigger_service.sh /etc/init.d/
# chkconfig --add service
chkconfig --add kdump_trigger_service.sh
# chkconfig service on
chkconfig kdump_trigger_service.sh on
if [ $? -ne 0 ]
then
	LogMsg "FAIL: Could not setup kdump_trigger_service.sh."
	UpdateSummary "FAIL: Could not setup kdump_trigger_service.sh."
	exit 1
else
	LogMsg "PASS: Setup kdump_trigger_service.sh well."
	UpdateSummary "PASS: Setup kdump_trigger_service.sh well."
fi

# Prepare for trigger kdump
LogMsg "Prepare for kernel panic......."
UpdateSummary "Prepare for kernel panic......."
if [ -f $proc_sys_kernel_sysrq ]
then	
	LogMsg "PASS: $proc_sys_kernel_sysrq esxits."
	UpdateSummary "PASS: $proc_sys_kernel_sysrq esxits."
	echo 1 > $proc_sys_kernel_sysrq
else
	LogMsg "FAIL: $proc_sys_kernel_sysrq doesn't esxit."
	UpdateSummary "FAIL: $proc_sys_kernel_sysrq doesn't esxit."
	exit 1
fi
