#!/bin/bash

###############################################################################
##
## Description:
## Run growpart and check if can resize partition with MBR(msdos) partition table
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 07/06/2020 - Build the script
##
###############################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
	echo "Error: unable to source utils.sh!"
	exit 1
}

# Source constants.sh to get all paramters from XML <testParams>
. constants.sh || {
	echo "Error: unable to source constants.sh!"
	exit 1
}

# Source constants file and initialize most common variables
UtilsInit

###############################################################################
##
## Main
##
###############################################################################
#Install resize tools cloud-utils-growpart
yum install -y cloud-utils-growpart
if [ ! "$?" -eq 0 ]; then
	LogMsg "Test Failed.Install cloud-utils-growpart failed."
	UpdateSummary "Test failed.Install cloud-utils-growpart failed."
	SetTestStateAborted
	exit 1
else
	LogMsg " Install cloud-utils-growpart successfully."
	UpdateSummary "Install cloud-utils-growpart successfully."
fi

#Check the new added Test disk exist.
ls /dev/$disk
if [ ! "$?" -eq 0 ]; then
	LogMsg "Test Failed.Test disk /dev/$disk not exist."
	UpdateSummary "Test failed.Test disk /dev/$disk not exist."
	SetTestStateAborted
	exit 1
else
	LogMsg " Test disk /dev/$disk exist."
	UpdateSummary "Test disk /dev/$disk exist."
fi

# Do Partition for Test disk with mbr(msdos) lable.
parted /dev/$disk mklabel msdos
parted -s /dev/$disk mkpart primary xfs 0 1000 

# Get new partition
kpartx /dev/$disk
if [ ! "$?" -eq 0 ]; then
	LogMsg "Create partition with gpt failed."
	UpdateSummary "FAIL: Create partition with gpt failed"
	SetTestStateAborted
	exit 1
else
	LogMsg "Create partition with gpt successfully."
	UpdateSummary "Passed:Create partition with gpt successfully."
fi

#Resize the partition
growpart /dev/$disk 1 
if [ $? -ne 0 ]; then
	LogMsg "Resize the partition failed"
	UpdateSummary "Resize the partition failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "Resize the partition successfully"
	UpdateSummary "Resize the partition successfully"
	SetTestStateCompleted
	exit 0
fi

