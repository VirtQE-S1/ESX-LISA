#!/bin/bash


###############################################################################
##
## Description:
## 	Check NIC operstate when ifup / ifdown
##
## Revision:
## 	v1.0.0 - boyang - 08/31/2017 - Build the script
## 	v1.0.1 - boyang - 05/14/2018 - Remove network restart
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
    cp $network_scripts/ifcfg-$i $ifcfg_orignal
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
	fi
	
	if [[ $DISTRO == "redhat_7" ]]
	then
		systemctl stop NetworkManager
		systemctl disable NetworkManager
		status_networkmanager_stop=`systemctl status NetworkManager`
		LogMsg "DEBUG: status_networkmanager_stop: $status_networkmanager_stop"
		UpdateSummary "DEBUG: status_networkmanager_stop: $status_networkmanager_stop"		
	fi
	
	if [[ $DISTRO == "redhat_8" ]]
	then
		systemctl stop NetworkManager
		systemctl disable NetworkManager
		status_networkmanager_stop=`systemctl status NetworkManager`
		LogMsg "DEBUG: status_networkmanager_stop: $status_networkmanager_stop"
		UpdateSummary "DEBUG: status_networkmanager_stop: $status_networkmanager_stop"
	fi
}

#
# Confirm which nics are added newly, and setup their ifcfg files, test their ifup / fidown functions
#
for i in $nics
do
    if [ ! -f $network_scripts/ifcfg-$i ]
    then
		CreateIfcfg $i
		
		StopNetworkManager
		
        LogMsg "INFO: Is checking operstate under ifdown"
		UpdateSummary "INFO: Is checking operstate under ifdown"
        ifdown $i
        if [ $? -eq 0 ]
        then
            # Check operstate under ifdown
            operstate=`cat /sys/class/net/$i/operstate`
            if [ "$operstate" == "down" ]
            then
                LogMsg "INFO: ifdown works well and operstate status $operstate under ifdown is correct"
                UpdateSummary "INFO: ifdown works well and operstate status $operstate under ifdown is correct"

                # Check operstate under ifup
                LogMsg "INFO: Is checking operstate under ifup"
                UpdateSummary "INFO: checking operstate under ifup"
                ifup $i
                if [ $? -eq 0 ]
                then
                    # Check operstate
                    operstate=`cat /sys/class/net/$i/operstate`
                    if [ "$operstate" == "up" ]
                    then
                        LogMsg "PASS: $i ifup works well and operstate status $operstate under ifup is correct"
                        UpdateSummary "PASS: $i ifup works well and operstate status $operstate under ifup is correct"
                        SetTestStateCompleted
			
                        LogMsg "INFO: Ifdown $i again to avoid mulit IP"
                        UpdateSummary "INFO: Ifdown $i again to avoid mulit IP"
                        ifdown $i
						exit 0
                    else
                        LogMsg "FAIL: operstate status is incorrect"
                        UpdateSummary "FAIL: operstate status is incorrect"
                        SetTestStateFailed
                        exit 1
                    fi
                else
                {
                    LogMsg "FAIL: $i ifup failed"
                    UpdateSummary "FAIL: $i ifup failed"
                    SetTestStateAborted
                    exit 1
                }
                fi
            else
                LogMsg "FAIL: operstate status is incorrect"
                UpdateSummary "FAIL: operstate status is incorrect"
                SetTestStateFailed
                exit 1
            fi
        else
        {
            LogMsg "FAIL: $i ifdown failed"
            UpdateSummary "FAIL: $i ifdown failed"
            SetTestStateAborted
            exit 1
        }
        fi
    fi
done
