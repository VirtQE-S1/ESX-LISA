#!/bin/bash


###############################################################################
##
## Description:
##  Checks /etc/vmware-tools and /etc/vmware-tools/scripts path.
##
## Revision:
##  v1.0.0 - ldu - 03/29/2018 - Draft script for case ESX-OVT-031
##  v1.0.1 - boyang - 05/15/2018 - Fix no yum-utils to install
##
###############################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


#######################################################################
#
# Main script body
#
#######################################################################


if [[ $DISTRO == "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi


# Install download package for yum
yum install yum-utils* -y
if [ $? -ne 0]
then
    LogMsg "ERROR: Install yum-utils tools failed before test start"
    UpdateSummary "ERROR: Install yum-utils tools failed before test start"
    SetTestStateAborted
    exit 1
fi


# Download open-vm-tools package
yumdownloader open-vm-tools
# Check the directories in the open-vm-tools RPM
direc_count=`rpm -qlp open-vm-tools*.rpm |grep "/etc/vmware-tools" |wc -l`
if [[ $direc_count -gt 22 ]]; then
    LogMsg "Test successfully. There's $direc_count directories under /etc/vmware-tools."
    UpdateSummary "Test successfully. There's $direc_count directories under /etc/vmware-tools."
    SetTestStateCompleted
    exit 0
else
    LogMsg "Test Failed. The /etc/vmware-tools directories count is not right in ovt rpm."
    UpdateSummary "Test failed. The /etc/vmware-tools directories count is not right in ovt rpm."
    SetTestStateFailed
    exit 1
fi
