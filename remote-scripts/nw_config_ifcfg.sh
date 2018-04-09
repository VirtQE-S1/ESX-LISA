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


# Get all NICs interfaces
nics=`ls /sys/class/net | grep ^e[tn][hosp]`
network_scripts="/etc/sysconfig/network-scripts"
ifcfg_bk="/root/ifcfg-orignal"


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
# Confirm which nics are new
# Setup their ifcfg files
# Test their ifup / fidown functions
#
for i in $nics
do
    if [ ! -f $network_scripts/ifcfg-$i ]
    then
        # New NIC needs to create its ifcfg file based on orignal nic's script
        LogMsg "INFO: $i is a new NIC, will create ifcfg-$i"
        UpdateSummary "INFO: $i is a new NIC, will create ifcfg-$i"
        cp $ifcfg_bk $network_scripts/ifcfg-$i
        
        # Comment UUID
        LogMsg "INFO: Commenting UUID"
        UpdateSummary "INFO: Commenting UUID"
        sed -i '/^UUID/ s/UUID/#UUID/g' $network_scripts/ifcfg-$i
		
		# Comment HWADDR
        LogMsg "INFO: Commenting HWADDR"
        UpdateSummary "INFO: Commenting HWADDR"
        sed -i '/^HWADDR/ s/HWADDR/#HWADDR/g' $network_scripts/ifcfg-$i
        
        # Comment original DEVICE
        LogMsg "INFO: Commenting DEVICE"
        UpdateSummary "INFO: Commenting DEVICE"
        sed -i '/^DEVICE/ s/DEVICE/#DEVICE/g' $network_scripts/ifcfg-$i
		
        # Add a new DEVICE
        LogMsg "INFO: New a line for DEVICE"
        UpdateSummary "INFO: New a line for DEVICE"      
        echo "DEVICE=\"$i\"" >> $network_scripts/ifcfg-$i    
        
        # Comment original NAME
        LogMsg "INFO: Commenting NAME"
        UpdateSummary "INFO: Commenting NAME"
        sed -i '/^NAME/ s/NAME/#NAME/g' $network_scripts/ifcfg-$i
		
        # Add a new NAME
        LogMsg "INFO: New a line for NAME"
        UpdateSummary "INFO: New a line for NAME"      
        echo "NAME=\"$i\"" >> $network_scripts/ifcfg-$i
  
  
        #
        # Test new NIC ifup / ifdown. No ping function to test
        # Firstly, stop SELINUX, NetworkManager, and restart network
        #
        RestartNetwork()
        {	
			if [[ $DISTRO -eq "redhat_7" ]]
			then
				systemctl stop NetworkManager
				systemctl restart network
			fi
			
			if [[ $DISTRO -eq "redhat_6" ]]
			then
				service NetworkManager stop
				service network restart
			fi
			
			if [[ $DISTRO -eq "redhat_8" ]]
			then
				LogMsg "DEBUG: Use RHEL7 mehtods to RHEL8"
				UpdateSummary "DEBUG: Use RHEL7 mehtods to RHEL8"				
				systemctl stop NetworkManager
				systemctl restart network
			fi			
        }
        
		
        # Test ifup function for new NICs
        LogMsg "INFO: Testing ifup function"
        UpdateSummary "INFO: Testing ifup function" 
        
		setenforce 0
		
		ifup $i
        if [ $? -eq 0 ]
        then
            LogMsg "DONE: $i ifup works well"
            UpdateSummary "DONE: $i ifup works well"
			
			
            # Test ifdown function for new NICs
            LogMsg "INFO: Testing ifdown function"
            UpdateSummary "INFO: Testing ifdown function" 
            ifdown $i
            if [ $? -eq 0 ]
            then
                LogMsg "PASS: Both ifdown and ifup work well"
                UpdateSummary "PASS: Both ifdown and ifup work well"
                SetTestStateCompleted
				
                mv $network_scripts/ifcfg-$i /root/
				
				# If no restart network, original NIC also can't be used
				RestartNetwork               

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
