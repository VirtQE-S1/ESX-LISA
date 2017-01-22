#!/bin/bash

###############################################################################
##
## Description:
##   Config kdump.conf and grub.conf
##   Config kdump.conf and grub.conf based on requirment
##
###############################################################################
##
## Revision:
## v1.0 - boyang - 18/01/2017 - Build script.
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

kdump_conf="/etc/kdump.conf"
dump_path="/var/crash"

# Re-write /etc/grub.conf, cant' update $crashkernel 
# RHEL6 BIOS, re-write /boot/grub/grub.conf to update $crashkernel
# RHEL6 EFI, re-write /boot/efi/EFI/redhat/grub.conf to update $crashkernel
rhel6_grub=`find /boot/ -name "grub.conf"`
# No matter BIOS or EFI, they have the same grub in RHEL7
rhel7_grub="/etc/default/grub"

grub_conf=""

crashkernel=$1

###############################################################################
##
## Config_Kdump()
##  No matter VM is RHEL6 or RHEL7, will set the same rules for kdump.conf
##
###############################################################################

Config_Kdump(){
	if [ -f $kdump_conf ]
	then
		LogMsg "PASS. Find out kdump.conf file in VM."
		UpdateSummary "PASS. Find out kdump.conf file in VM."

		# Modify path to /var/crash
		LogMsg "Start to modify $kdump_conf......."
		UpdateSummary "Start to modify $kdump_conf......."
		sed -i '/^path/ s/path/#path/g' $kdump_conf
    		if [ $? -ne 0 ]
		then
			LogMsg "ERROR: Failed to comment path in /etc/kdump.conf. Probably kdump is not installed."
		       	UpdateSummary "ERROR: Failed to comment path in /etc/kdump.conf. Probably kdump is not installed."
        		SetTestStateFailed
        		exit 1
		else
			echo "path $dump_path" >> $kdump_conf
			LogMsg "SUCCESS: Updated the path to /var/crash."
			UpdateSummary "SUCCESS: Updated the path to /var/crash."
		fi

		# Modify default action as reboot after crash
		sed -i '/^default/ s/default/#default/g' $kdump_conf
		grep -iq "^#default" $kdump_conf
		if [ $? -ne 0 ]; then
			LogMsg "ERROR: Failed to comment default action in /etc/kdump.conf. Probably kdump is not installed."
		       	UpdateSummary "ERROR: Failed to comment default action in /etc/kdump.conf. Probably kdump is not installed."
        		SetTestStateFailed
        		exit 1
		else
			echo "default reboot" >> $kdump_conf
			LogMsg "SUCCESS: Updated the default action reboot after kdump."
			UpdateSummary "SUCCESS: Updated the default action reboot after kdump."
		fi

		# Modify vmcore collection method and level
		sed -i '/^core_collector/ s/core_collector/#core_collector/g' $kdump_conf
		grep -iq "^#core_collector" $kdump_conf
		if [ $? -ne 0 ]; then
			LogMsg "ERROR: Failed to comment vmcore collection method in /etc/kdump.conf. Probably kdump is not installed."
			UpdateSummary "ERROR: Failed to comment vmcore collection method in /etc/kdump.conf. Probably kdump is not installed."
        		SetTestStateFailed
        		exit 1
		else
			echo "core_collector makedumpfile -c --message-level 1 -d 31" >> $kdump_conf
			LogMsg "SUCCESS: Updated vmcore collection method to makedumpfile."
			UpdateSummary "SUCCESS: Updated vmcore collection method to makedumpfile."
		fi

	else
		LogMsg "Failed. Can't find out kdump.conf file or not a file."
		UpdateSummary "Failed. Can't find out kdump.conf file in VM."
		SetTestStateFailed
		exit 1
	fi

}

###############################################################################
##
## Config_Grub()
##  Based on $DISTRO, will confirm $grub_conf value to modify $crashkernel
##
###############################################################################

Config_Grub(){
		echo "DISTRO is $DISTRO, both BIOS and EFI mode will modify $grub_conf."
		grub_conf=$1
		if [ -f $grub_conf ]
		then
			LogMsg "PASS. Find out grub file in VM."
			UpdateSummary "PASS. Find out grub file in VM."

			# Modify crashkernel as $crashkernel
			if grep -iq "crashkernel=" $grub_conf
			then
				sed -i "s/crashkernel=\S*/crashkernel=$crashkernel/g" $grub_conf
			fi

			grep -iq "crashkernel=$crashkernel" $grub_conf
			if [ $? -ne 0 ]; then
				LogMsg "FAIL: Could not set the new crashkernel value in /etc/default/grub."
				UpdateSummary "FAIL: Could not set the new crashkernel value in /etc/default/grub."
				SetTestStateFailed
				exit 1
			else
				LogMsg "SUCCESS: updated the crashkernel value to: $crashkernel."
				UpdateSummary "SUCCESS: updated the crashkernel value to: $crashkernel."
			fi

		else
			LogMsg "Failed. Can't find out grub file or not a file."
			UpdateSummary "Failed. Can't find out grub file in VM."
			SetTestStateFailed
		fi

}

# Ensure script start to execute in /root
cd ~

# Both RHEL6 and RHEL7 set kdump.conf as the same rules
Config_Kdump

# Based on DISTRO to modify grub.conf or grub
case $DISTRO in
	redhat_6)
		grub_conf=$rhel6_grub
		Config_Grub $grub_conf
	;;
	redhat_7)
		$grub_conf=$rhel7_grub
		Config_Grub $grub_conf

		grub2-mkconfig -o /boot/grub2/grub.cfg
		if [ $? -ne 0 ]
		then
			LogMsg "FAIL: Could not execute grub2-mkconfig."
			UpdateSummary "FAIL: Could not grub2-mkconfig."
			SetTestStateFailed
			exit 1
		else
			LogMsg "SUCCESS: Execute grub2-mkconfig well."
			UpdateSummary "SUCCESS: Execute grub2-mkconfig well."
		fi
	;;
	*)
		LogMsg "FAIL: Unknow OS"
		UpdateSummary "FAIL: Unknow OS"
		exit 1
	;;
		
esac

# Restart kdump.service
service kdump restart
if [ $? -ne 0 ]
then
	LogMsg "FAIL: Could not restart kdump service, maybe new parameters in $kdump_conf has problems"
	UpdateSummary "FAIL: Could not restart kdump service, maybe new parameters in $kdump_conf has problems"
	SetTestStateFailed
	exit 1
else
	LogMsg "SUCCESS: Could restart kdump service well with new parameters."
	UpdateSummary "SUCCESS: Could restart kdump service well with new parameters."
fi

# Cleaning up any previous crash dump files
if [ -d $dump_path ]
then
	LogMsg "SUCCESS: $dump_path esxits, will clean up any vmcores."	
	UpdateSummary "SUCCESS: $dump_path esxits, will clean up any vmcores."	
	rm -rf $dump_path/*
else
	LogMsg "WARNING: $dump_path doesn't esxit, will create it."	
	UpdateSummary "WARNING: $dump_path doesn't esxit, will create it."	
fi

SetTestStateCompleted
