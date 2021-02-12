#!/bin/bash


########################################################################################
##	Description:
##		Config kdump.conf and grub.conf
##
##	Revision:
##		v1.0.0 - boyang - 01/18/2017 - Build the script.
##		v1.1.0 - boyang - 02/23/2017 - Remove kdump restart after configuration.
##		v2.0.0 - boyang - 11/30/2020 - Support RHEL-9.0.0.
########################################################################################


# Source utils.sh.
dos2unix utils.sh
. utils.sh || {
	echo "ERROR: unable to source utils.sh."
	exit 1
}


# Source constants file and initialize most common variables.
UtilsInit


########################################################################################
## Main Body
########################################################################################
kdump_conf="/etc/kdump.conf"
dump_path="/var/crash"


# Re-write grub.conf file, or cant' update $crashkernel.
# RHEL-6 BIOS, re-write /boot/grub/grub.conf to update $crashkernel.
# RHEL-6 EFI, re-write /boot/efi/EFI/redhat/grub.conf to update $crashkernel.
rhel6_grub_conf=`find /boot/ -name "grub.conf"`

# For RHEL-7, RHEL-8, RHEL-9 or highter, they own the same grub file names and grub config files.
rhel7_p_grub="/etc/default/grub"
rhel7_p_grub_cfg=`find /boot/ -name "grub.cfg"`

grub_conf=""
crashkernel=$1
if [ -z $crashkernel ]; then
	LogMsg "ERROR: crashkernel value can't be set null."
	UpdateSummary "ERROR: crashkernel value can't be set null."
	SetTestStateFailed
	exit 1
fi


########################################################################################
## Config_Kdump()
## No matter VM is RHEL-X, will set the same rules for kdump.conf
########################################################################################
Config_Kdump() {
	if [ -f $kdump_conf ]
	then
		LogMsg "INFO: Find out the $kdump_conf file in target VM."
		UpdateSummary "INFO: Find out the $kdump_conf file in target VM."

		# Modify path to /var/crash.
		LogMsg "INFO: Start to modify ${kdump_conf}."
		UpdateSummary "INFO: Start to modify ${kdump_conf}."
		sed -i '/^path/ s/path/#path/g' $kdump_conf
		grep -iq "^#path" $kdump_conf
		if [ $? -ne 0 ]
		then
			LogMsg "ERROR: Failed to comment path in /etc/kdump.conf. Probably kdump is not installed, or kdump.conf content has been changed."
			UpdateSummary "ERROR: Failed to comment path in /etc/kdump.conf. Probably kdump is not installed, or kdump.conf content has been changed."
			SetTestStateFailed
			exit 1
		else
			echo "path $dump_path" >> $kdump_conf
			LogMsg "INFO: Updated the path to ${dump_path}."
			UpdateSummary "INFO: Updated the path to ${dump_path}."
		fi

		# Modify vmcore collection method and level.
		sed -i '/^core_collector/ s/core_collector/#core_collector/g' $kdump_conf
		grep -iq "^#core_collector" $kdump_conf
		if [ $? -ne 0 ]
		then
			LogMsg "ERROR: Failed to comment vmcore collection method in $kdump_conf. Probably kdump is not installed."
			UpdateSummary "ERROR: Failed to comment vmcore collection method in $kdump_conf. Probably kdump is not installed."
			SetTestStateFailed
			exit 1
		else
			echo "core_collector makedumpfile -c --message-level 1 -d 31" >> $kdump_conf
			LogMsg "INFO: Updated vmcore collection method to makedumpfile."
			UpdateSummary "INFO: Updated vmcore collection method to makedumpfile."
		fi
	else
		LogMsg "ERROR: Can't find out the $kdump_conf file in target VM."
		UpdateSummary "ERROR: Can't find out the $kdump_conf file in target VM."
		SetTestStateFailed
		exit 1
	fi
}


########################################################################################
## Config_Grub()
## Based on $DISTRO, will confirm $grub_conf value to modify $crashkernel
########################################################################################
Config_Grub() {
		LogMsg "INFO: DISTRO is $DISTRO, both BIOS and EFI modes will modify grub file ${1}."
		UpdateSummary "INFO: DISTRO is $DISTRO, both BIOS and EFI modes will modify grub file ${1}."
		if [ -f $1 ]
		then
			LogMsg "INFO: Find out the $1 grub file in the VM."
			UpdateSummary "INFO: Find out the $1 grub file in the VM."

			# Modify crashkernel as $crashkernel
			if grep -iq "crashkernel=" $1
			then
				LogMsg "INFO: Find the crashkernel filed in the ${1}, modify it with crashkernel=${crashkernel}."
				UpdateSummary "INFO: Find the crashkernel filed in ${1}, modify it with crashkernel=${crashkernel}."
				sed -i "s/crashkernel=\S*/crashkernel=$crashkernel/g" $1
			else
				LogMsg "INFO: Can't find a crashkernel filed in ${1}. Set a new 'crashkernel=${crashkernel}' for it."
				UpdateSummary  "INFO: Can't find a crashkernel filed in ${1}. Set a new 'crashkernel=${crashkernel}' for it."
				sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"crashkernel=$crashkernel /g" $1
			fi

			# Verify above settings.
			grep -iq "crashkernel=$crashkernel" $1
			if [ $? -ne 0 ]
			then
				LogMsg "ERROR: Could not set the new crashkernel=${crashkernel} in the ${1}."
				UpdateSummary "ERROR: Could not set the new crashkernel=${crashkernel} in the ${1}."
				SetTestStateFailed
				exit 1
			else
				LogMsg "INFO: Updated the crashkernel value to: ${crashkernel}."
				UpdateSummary "INFO: Updated the crashkernel value to: ${crashkernel}."
			fi
		else
			LogMsg "ERROR: Can't find out the grub file or not a file."
			UpdateSummary "ERROR: Can't find out the grub file in the VM."
			SetTestStateFailed
			exit 1			
		fi
}


# Set kdump.conf as the same rules.
Config_Kdump


# Based on DISTRO to modify grub configuration.
case $DISTRO in
	redhat_6)
		grub_conf=$rhel6_grub_conf
		Config_Grub $grub_conf
	;;
	redhat_[7-9])
		grub_conf=$rhel7_p_grub
		Config_Grub $grub_conf
		grub2-mkconfig -o $rhel7_p_grub_cfg
		if [ $? -ne 0 ]
		then
			LogMsg "ERROR: Failed to run grub2-mkconfig."
			UpdateSummary "ERROR: Failed to run grub2-mkconfig."
			SetTestStateFailed
			exit 1
		else
			LogMsg "INFO: Run grub2-mkconfig well."
			UpdateSummary "INFO: Run grub2-mkconfig well."
		fi
	;;
	*)
		LogMsg "ERROR: Unknow OS."
		UpdateSummary "ERROR: Unknow OS."
		SetTestStateFailed
		exit 1
	;;
esac


# Cleaning up any previous vmcore files.
if [ -d $dump_path ]
then
	LogMsg "INFO: $dump_path esxits, will clean up any vmcores."
	UpdateSummary "INFO: $dump_path esxits, will clean up any vmcores."
	rm -rf $dump_path/*
else
	LogMsg "WARNING: $dump_path doesn't exist, will create it."
	UpdateSummary "WARNING: $dump_path doesn't exist, will create it."
	mkdir -p $dump_path
	if [ $? -ne 0 ]
	then
		LogMsg "ERROR: Failed to mkdir ${dump_path}."
		UpdateSummary "ERROR: Failed to mkdir ${dump_path}."
		SetTestStateFailed		
		exit 1
	else
		LogMsg "INFO: Make $dump_path well."
		UpdateSummary "INFO: Make $dump_path well."
		SetTestStateCompleted
		exit 0
	fi
fi

