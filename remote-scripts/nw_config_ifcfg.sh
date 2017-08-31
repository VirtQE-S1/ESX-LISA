#!/bin/bash

###############################################################################
##
## Description:
##   Config new NICs ifcfg scripts
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
#
for i in $nics
do
    LogMsg "Now, checking $i......."
	UpdateSummary "Now, checking $i......."
    if [ ! -f $network_scripts/ifcfg-$i ]
    then
        #
        # New NIC needs to create its ifcfg scripts based on orignal nic's script
        #
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
        # Add new NIC name to script
        LogMsg "Now, adding new DEVICE"
        UpdateSummary "Now, add new DEVICE"      
        echo "DEVICE=\"$i\"" >> $network_scripts/ifcfg-$i
        
        #
        # Test new NIC ifup, if ifup passed, will go on test ifdown
        # Firstly, close selinux
        #
        setenforce 0
        LogMsg "Now, test ifdown function"
        UpdateSummary "Now, test ifdown function" 
        ifdown $i
        if [ $? -eq 0 ]
        then
            LogMsg "DONE. $i ifdown works well"
            UpdateSummary "DONE. $i ifdown works well"
            #
            # Test new NIC ifup / ifdown
            #
            LogMsg "Now, test ifup function"
            UpdateSummary "Now, test ifup function" 
            ifup $i
            if [ $? -eq 0 ]
            then
                LogMsg "PASS. $i both ifup and ifdown work well"
                UpdateSummary "PASS. $i both ifup and ifdown work well"
                SetTestStateCompleted
            else
            {
                LogMsg "FAIL. $i ifup failed"
                UpdateSummary "FAIL. $i ifup failed"
                SetTestStateFailed
                exit 1
            }
            fi
        else
        {
            LogMsg "FAIL. $i ifdown failed"
            UpdateSummary "FAIL. $i ifdown failed"
            SetTestStateFailed
            exit 1
        }
        fi
    fi
done
