#!/bin/bash

###############################################################################
##
## Description:
## SCP big file with MTU = 90000
##
###############################################################################
##
## Revision:
## v1.0 - boyang - 10/19/2017 - Build script
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

tempFile="5-1G.img"
# sshPrivateKey: all VM own this private key and all VM own the same public key
sshPrivateKey="id_rsa_private"
# Get the target NIC interfaces
sys_class="/sys/class/net"
nics=`ls $sys_class | grep ^e[tn][hosp]`

#
# Default VM MTU = 1500
# Change MTU to 9000
#
ifconfig $nics mtu 9000
if [ $? -eq 0 ]
then
    LogMsg "PASS: $nics mtu value setting passed"
    UpdateSummary "PASS: $nics mtu value setting passed"
else
    LogMsg "WARNING: $nics mtu value setting failed"
    UpdateSummary "WARNING: $nics mtu value setting failed"
    SetTestStateAborted
    exit 1    
fi

# Generate 5.1G 
dd if=/dev/zero of=/root/$tempFile bs=1M count=5222
if [ $? -eq 0 ]
then
    LogMsg "PASS: Generate 5-1G.img passed"
    UpdateSummary "PASS: Generate 5-1G.img passed"
else
    LogMsg "WARNING: $nics mtu value setting failed"
    UpdateSummary "WARNING: $nics mtu value setting failed"
    SetTestStateAborted
    exit 1
fi

# SCP file to VMB with IP via private ky
scp -i $HOME/.ssh/$sshPrivateKey -o StrictHostKeyChecking=no /root/$tempFile root@$1:/root/
if [ $? -eq 0 ]
then
    LogMsg "PASS: SCP 5-1G.img to the VM B passed"
    UpdateSummary "PASS: SCP 5-1G.img to the VM B passed"
    SetTestStateCompleted
    exit 0
else
    LogMsg "FAIL: SCP 5-1G.img to the VM B failed"
    UpdateSummary "FAIL: SCP 5-1G.img to the VM B failed"
    SetTestStateFailed
    exit 1
fi
