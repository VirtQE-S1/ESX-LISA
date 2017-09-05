#!/bin/bash

###############################################################################
##
## Description:
## Check NIC operstate when ifup / ifdown
##
###############################################################################
##
## Revision:
## v1.0 - boyang - 08/31/2017 - Build script
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

# Get all NICs interfaces
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
# Confirm which nics are added newly
# Setup their ifcfg files
# Test their ifup / fidown functions
#
for i in $nics
do
    LogMsg "Now, checking $i......."
	UpdateSummary "Now, checking $i......."
    if [ ! -f $network_scripts/ifcfg-$i ]
    then
        # New NIC needs to create its ifcfg scripts based on orignal nic's script
        LogMsg "DONE. $i is a new one nic, will create ifcfg-$i fot $i"
        UpdateSummary "DONE. $i is a new one nic, will create ifcfg-$i fot $i"
        cp $ifcfg_orignal $network_scripts/ifcfg-$i
        
        # Comment UUID
        LogMsg "Now, commenting UUID"
        UpdateSummary "Now, commenting UUID"
        sed -i '/^UUID/ s/UUID/#UUID/g' $network_scripts/ifcfg-$i
        
        # Comment original DEVICE
        LogMsg "Now, commenting DEVICE"
        UpdateSummary "Now, commenting DEVICE"
        sed -i '/^DEVICE/ s/DEVICE/#DEVICE/g' $network_scripts/ifcfg-$i
        # Add a new DEVICE to script
        LogMsg "Now, adding a new DEVICE"
        UpdateSummary "Now, add a new DEVICE"      
        echo "DEVICE=\"$i\"" >> $network_scripts/ifcfg-$i    
        
        # Comment original NAME
        LogMsg "Now, commenting NAME"
        UpdateSummary "Now, commenting NAME"
        sed -i '/^NAME/ s/NAME/#NAME/g' $network_scripts/ifcfg-$i
        # Add a new NAME to script
        LogMsg "Now, adding a new NAME"
        UpdateSummary "Now, add a new NAME"      
        echo "NAME=\"$i\"" >> $network_scripts/ifcfg-$i
  
        #
        # Test new NIC ifup / ifdown. No ping function to test
        # Firstly, stop SELINUX, NetworkManager, and restart network
        #
        setenforce 0
        systemctl stop NetworkManager
        if [ $? -eq 0 ]
        then
            systemctl restart network
            if [ $? -ne 0 ]
            then
                SetTestStateAborted
                exit 1
            fi
        else
            service NetworkManager stop
            if [ $? -eq 0 ]
            then
                service network restart
                if [ $? -ne 0 ]
                then
                    SetTestStateAborted
                    exit 1
                fi
            else
                SetTestStateAborted
                exit 1
            fi
        fi
        
        #
        # Test checking operstate under ifup / ifdown
        # 
        LogMsg "Now, check operstate under ifdown"
        UpdateSummary "Now, check operstate under ifdown" 
        ifdown $i
        if [ $? -eq 0 ]
        then
            LogMsg "DONE: $i ifdown works well"
            UpdateSummary "DONE: $i ifdown works well"
            # Check operstate under ifdown
            operstate=`cat /sys/class/net/$i/operstate`
            if [ "$operstate" == "down" ]
            then
                LogMsg "DONE: Operstate status $operstate under ifdown is correct"
                UpdateSummary "DONE: Operstate status $operstate under ifdown is correct"
                
                # Check operstate under ifup 
                LogMsg "Now, check operstate under ifup"
                UpdateSummary "Now, check operstate under ifup" 
                ifup $i
                if [ $? -eq 0 ]
                then
                    LogMsg "DONE: $i ifup works well"
                    UpdateSummary "DONE: $i ifup works well"
                    # Check operstate
                    operstate=`cat /sys/class/net/$i/operstate`
                    if [ "$operstate" == "up" ]
                    then
                        LogMsg "PASS: Operstate status $operstate under ifup is correct"
                        UpdateSummary "PASS: Operstate status $operstate under ifup is correct"
                        SetTestStateCompleted
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
