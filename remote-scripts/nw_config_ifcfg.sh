#!/bin/bash


###############################################################################
#
# Description:
#	Config new NICs ifcfg scripts
#
# Notice:
#	Multi NICs, can't ping, if restart network well, it means geting IP well
#
# Revision:
# v1.0.0 - boyang - 01/18/2017 - Build script
# v1.0.1 - boyang - 04/02/2018 - Comment in Notice
# v1.0.2 - boyang - 04/03/2018 - Use $DISTRO to identify different operations
#
###############################################################################


dos2unix utils.sh


#
# Source utils.sh
#
. utils.sh || {
    LogMsg "ERROR: Unable to source utils.sh!"
	UpdateSummary "ERROR: Unable to source utils.sh!"
	exit 1
}


#
# Source constants file and initialize most common variables
#
UtilsInit


#######################################################################
#
# Main script body
#
#######################################################################


#
# Get all NICs interfaces
#
nics=`ls /sys/class/net | grep ^e[tn][hosp]`
network_scripts="/etc/sysconfig/network-scripts"
ifcfg_orignal="/root/ifcfg-orignal"


#
# Copy the orignal ifcfg file under $network_scripts to /root
#
for i in $nics
do
    if [ -f $network_scripts/ifcfg-$i ]
    then
		LogMsg "INFO: Copy original NIC ifcfg file to /root"
		UpdateSummary "INFO: Copy original NIC ifcfg file to /root"
		cp $network_scripts/ifcfg-$i $ifcfg_bk
		if [ $? -ne 0 ]
		then
			LogMsg "ERROR: Copy original NIC ifcfg file failed"
			UpdateSummary "ERROR: Copy original NIC ifcfg file failed"
			exit 1
		fi
    fi
done


#
# Create the ifcfg file for the new NIC
#
CreateIfcfg()
{
	# New NIC needs to create its ifcfg scripts based on orignal NIC's script
	LogMsg "INFO: $i is a new NIC, will create ifcfg-$i fot $i"
	UpdateSummary "INFO: $i is a new NIC, will create ifcfg-$i fot $i"
	cp $ifcfg_orignal $network_scripts/ifcfg-$1

	# Comment UUID
	LogMsg "INFO: Comment UUID"
	UpdateSummary "INFO: Comment UUID"
	sed -i '/^UUID/ s/UUID/#UUID/g' $network_scripts/ifcfg-$1

	# Comment HWADDR
	LogMsg "INFO: Comment HWADDR"
	UpdateSummary "INFO: Comment HWADDR"
	sed -i '/^HWADDR/ s/HWADDR/#HWADDR/g' $network_scripts/ifcfg-$1

	# Comment original DEVICE
	LogMsg "INFO: Comment DEVICE"
	UpdateSummary "INFO: Comment DEVICE"
	sed -i '/^DEVICE/ s/DEVICE/#DEVICE/g' $network_scripts/ifcfg-$1

	# Add a new DEVICE to script
	LogMsg "INFO: Is adding a new DEVICE"
	UpdateSummary "INFO: Is adding a new DEVICE"
	echo "DEVICE=\"$i\"" >> $network_scripts/ifcfg-$1

	# Comment original NAME
	LogMsg "INFO: Comment NAME"
	UpdateSummary "INFO: Comment ENVVISUSERNAME"
	sed -i '/^NAME/ s/NAME/#NAME/g' $network_scripts/ifcfg-$1

	# Add a new NAME to script
	LogMsg "INFO: Is adding a new NAME"
	UpdateSummary "INFO: Is adding a new NAME"
	echo "NAME=\"$i\"" >> $network_scripts/ifcfg-$1
}


#
# Stop NetowrkManager, as it will impact network
#
StopNetworkManager()
{
	# If getenforce == 1, even ifdown / ifup work well, $? -ne 0, as warning output
	setenforce 0

	# Different Guest DISTRO, different mehtods to stop NetworkManager
	if [[ $DISTRO == "redhat_6" ]]
	then
		service NetworkManager stop
		service NetowrkManager disable
		status_networkmanager_stop=`service NetworkManager status`
		LogMsg "DEBUG: status_networkmanager_stop: $status_networkmanager_stop"
		UpdateSummary "DEBUG: status_networkmanager_stop: $status_networkmanager_stop"
	else
        systemctl stop NetworkManager
        systemctl disable NetworkManager
        status_networkmanager_stop=`systemctl status NetworkManager`
        LogMsg "DEBUG: status_networkmanager_stop: $status_networkmanager_stop"
        UpdateSummary "DEBUG: status_networkmanager_stop: $status_networkmanager_stop"
    fi
}


#
# Confirm which nics are new
# Setup their ifcfg files
# Test their ifup / fidown functions
#
for i in $nics
do
    if [ ! -f $network_scripts/ifcfg-$i ]
    then
        CreateIfcfg

        StopNetworkManager

        # Test ifup function for new NICs
        LogMsg "INFO: Testing ifup function"
        UpdateSummary "INFO: Testing ifup function"
		ifup $i
        if [ $? -eq 0 ]
        then
            LogMsg "INFO: $i ifup works well"
            UpdateSummary "INFO: $i ifup works well"

            # Test ifdown function for new NICs
            LogMsg "INFO: Testing ifdown function"
            UpdateSummary "INFO: Testing ifdown function"
            ifdown $i
            if [ $? -eq 0 ]
            then
                LogMsg "PASS: Both ifdown and ifup work well"
                UpdateSummary "PASS: Both ifdown and ifup work well"
                # SHOULD CLEAN the new NIC config file and ifdown
                SetTestStateCompleted
                exit 0
            else
            {
                LogMsg "FAIL: $i ifdown failed"
                UpdateSummary "FAIL: $i ifdown failed"
                SetTestStateFailed
                exit 1
            }
            fi
        else
        {
            LogMsg "FAIL: $i ifup failed"
            UpdateSummary "FAIL: $i ifup failed"
            SetTestStateFailed
            exit 1
        }
        fi
    fi
done
