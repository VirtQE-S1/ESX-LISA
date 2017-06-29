#!/bin/bash
#chkconfig:2345 80 90
#description: restart kdump and trigger

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

# As NMI, can't triggered in Linux ENV. Will put it here firstly.
# ConfigureNMI

# Restart kdump.service after reboot and modification.
service kdump restart
if [ $? -ne 0 ]
then
	LogMsg "FAIL: Could not restart kdump service with new parameters after reboot."
	UpdateSummary "FAIL: Could not restart kdump service with new parameters after reboot."
	exit 1
else
	LogMsg "PASS: Could restart kdump service well with new parameters after reboot."
	UpdateSummary "PASS: Could restart kdump service well with new parameters after reboot."
fi

# Ensure kdump service status.
Check_Kdump_Running

LogMsg "Preparing for kernel panic......."
UpdateSummary "Preparing for kernel panic......."
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

# Off and del itself to void trigger forever, later trigger kdump
chkconfig kdump_trigger.sh off
chkconfig --del kdump_trigger.sh

sleep 60

echo c > /proc/sysrq-trigger
