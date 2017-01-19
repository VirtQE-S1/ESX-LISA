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

rhel6_grub="/etc/grub.conf"
rhel7_grub="/etc/default/grub"

grub_conf=""

crashkernel=$1

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
			LogMsg "Success: Updated the path to /var/crash."
			UpdateSummary "Success: Updated the path to /var/crash."
		fi

		# Modify default action as reboot after crash
		sed -i '/^default/ s/default/#default/g' $kdump_conf
		if [ $? -ne 0 ]
		then
			LogMsg "ERROR: Failed to comment default behaviour in /etc/kdump_conf. Probably kdump is not installed."
			UpdateSummary "ERROR: Failed to comment default behaviour in /etc/kdump.conf. Probably kdump is not installed."
        		SetTestStateFailed
			exit 1
		else
			echo 'default reboot' >>  $kdump_conf
			LogMsg "Success: Updated the default behaviour to reboot."
			UpdateSummary "Success: Updated the default behaviour to reboot."
		fi

	else
		LogMsg "Failed. Can't find out kdump.conf file or not a file."
		UpdateSummary "Failed. Can't find out kdump.conf file in VM."
		SetTestStateFailed
		exit 1
	fi

}

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
				LogMsg "FAILED: Could not set the new crashkernel value in /etc/default/grub."
				UpdateSummary "FAILED: Could not set the new crashkernel value in /etc/default/grub."
				SetTestStateFailed
				exit 1
			else
				LogMsg "Success: updated the crashkernel value to: $crashkernel."
				UpdateSummary "Success: updated the crashkernel value to: $crashkernel."
			fi
			
		else
			LogMsg "Failed. Can't find out grub file or not a file."
			UpdateSummary "Failed. Can't find out grub file in VM."
			SetTestStateFailed
		fi
	
}


cd ~

# Both RHEL6 and RHEL7 set kdump.conf as the same rules
Config_Kdump

# Based on DISTRO to modify grub.conf or grub
case $DISTRO in 
	redhat_6)
		$grub_conf=$rhel6_grub
		Config_grub $grub_conf
	redhat_7)
		$grub_conf=$rhel7_grub
		Config_grub $grub_conf

		grub2-mkconfig -o /boot/grub2/grub.cfg
		if [ $? -ne 0 ]
		then
			LogMsg "FAILED: Could not execute grub2-mkconfig."
			UpdateSummary "FAILED: Could not grub2-mkconfig."
			SetTestStateFailed
			exit 1
		else
			LogMsg "Success: Execute grub2-mkconfig well."
			UpdateSummary "Success: Execute grub2-mkconfig well."
		fi
esac

# Restart kdump.service
service kdump restart
if [ $? -ne 0 ]
then
	LogMsg "FAILED: Could not restart kdump service."
	UpdateSummary "FAILED: Could not restart kdump service."
	SetTestStateFailed
	exit 1
else
	LogMsg "SUCCESS: Could restart kdump service well."
	UpdateSummary "SUCCESS: Could restart kdump service well."
fi

# Cleaning up any previous crash dump files
rm -rf /var/crash/*
