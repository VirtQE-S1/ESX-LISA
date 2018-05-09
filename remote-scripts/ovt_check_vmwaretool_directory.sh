#!/bin/bash

###############################################################################
##
## Description:
##   This script checks /etc/vmware-tools and /etc/vmware-tools/scripts path.
##   RHEL7-52263
##
# <test>
#     <testName>ovt_check_vmwaretool_directory</testName>
#     <testID>ESX-OVT-00</testID>
#     <testScript>ovt_check_vmwaretool_directory.sh</testScript>
#     <files>remote-scripts/ovt_check_vmwaretool_directory.sh</files>
#     <files>remote-scripts/utils.sh</files>
#     <testParams>
#         <param>TC_COVERED=RHEL6-34904,RHEL7-52263</param>
#     </testParams>
#     <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
#     <timeout>240</timeout>
#     <onError>Continue</onError>
#     <noReboot>False</noReboot>
# </test>
###############################################################################
##
## Revision:
## v1.0 - ldu - 03/29/2018 - Draft script for case ESX-OVT-031.
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

#
# Start the testing
#

if [[ $DISTRO == "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi
#install download package for yum.
yum install yum-utils* -y
#download open-vm-tools package for check.
yumdownloader open-vm-tools
#Check the directories in the open-vm-tools RPM.
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
