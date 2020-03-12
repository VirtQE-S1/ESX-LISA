#!/bin/bash


########################################################################################
## Description:
## 	SCP big file with MTU = 90000
##
## Revision:
## 	v1.0.0 - boyang - 10/19/2017 - Build script
## 	v1.1.0 - boyang - 10/20/2017 - Install net-tools
########################################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
	echo "Error: unable to source utils.sh!"
	exit 1
}


# Source constants file and initialize most common variables
UtilsInit


########################################################################################
# Main script body
########################################################################################
tempFile="5-1G.img"


# sshPrivateKey: all VM own this private key and all VM own the same public key
sshPrivateKey="id_rsa_private"


# Get the target NIC interfaces
sys_class="/sys/class/net"
nics=`ls $sys_class | grep ^e[tn][hosp]`


# Maybe RHEL havn't net-tools including ifconfig
# Installtion result is put in "ifconfig $nics mtu 90000"
yum install -y net-tools


# Default VM MTU = 1500, change MTU to 9000
ifconfig $nics mtu 9000
if [ $? -eq 0 ]
then
    LogMsg "INFO: $nics mtu value setting passed."
    UpdateSummary "INFO: $nics mtu value setting passed."
else
    LogMsg "ERROR: $nics mtu value setting failed."
    UpdateSummary "ERROR: $nics mtu value setting failed, maybe no net-tools including ifconfig."
    SetTestStateAborted
    exit 1    
fi


# Generate 5.1G 
dd if=/dev/zero of=/root/$tempFile bs=1M count=5222
if [ $? -eq 0 ]
then
    LogMsg "INFO: Generate 5-1G.img passed"
    UpdateSummary "INFO: Generate 5-1G.img passed"
else
    LogMsg "ERROR: $nics mtu value setting failed"
    UpdateSummary "ERROR: $nics mtu value setting failed"
    SetTestStateAborted
    exit 1
fi


# SCP file to VMB with IP via private ky
scp -i $HOME/.ssh/$sshPrivateKey -o StrictHostKeyChecking=no /root/$tempFile root@$1:/root/
if [ $? -eq 0 ]
then
    LogMsg "INFO: SCP 5-1G.img to the VM B passed"
    UpdateSummary "INFO: SCP 5-1G.img to the VM B passed"
    SetTestStateCompleted
    exit 0
else
    LogMsg "ERROR: SCP 5-1G.img to the VM B failed"
    UpdateSummary "ERROR: SCP 5-1G.img to the VM B failed"
    SetTestStateFailed
    exit 1
fi
