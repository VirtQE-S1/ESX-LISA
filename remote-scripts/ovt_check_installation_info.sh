#!/bin/bash

###############################################################################
##
## Description:
##   This script install the open-vm-tools and check the installation info with no error.
##
##
###############################################################################
##
## Revision:
##  v1.0.0 - ldu - 03/24/2020 - Build scripts.
##
###############################################################################
#         <test>
#             <testName>ovt_check_installation_info</testName>
#             <testID>ESX-OVT-038</testID>
#             <testScript>ovt_check_installation_info.sh</testScript>
#             <files>remote-scripts/ovt_check_installation_info.sh</files>
#             <files>remote-scripts/utils.sh</files>
#             <testParams>
#                 <param>TC_COVERED=RHEL6-0000,RHEL-186495</param>
#             </testParams>
#             <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
#             <timeout>600</timeout>
#             <onError>Continue</onError>
#             <noReboot>False</noReboot>
#         </test>


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

yum erase -y open-vm-tools-desktop
yum erase -y open-vm-tools
version=$(rpm -qa open-vm-tools)
LogMsg "$version"
if [ -n "$version" ]; then
        LogMsg "unintall the open-vm-tools Failed"
        UpdateSummary "Test Failed. unintall the open-vm-tools Failed."
        SetTestStateAborted
        exit 1
else
        yum install -y open-vm-tools-desktop >> log.txt
        check=$(grep -e fail -e 'command not found' -e error log.txt)
        if [ -n "$check" ]; then
                LogMsg "open-vm-tools installed with error or warning message $check."
                UpdateSummary " open-vm-tools installed Failed with error or warning message $check."
                SetTestStateFailed
                exit 1
        else
                LogMsg "open-vm-tools installed successfully with no error or warning message $check."
                UpdateSummary " open-vm-tools installed successfully with no error or warning message $check."
                SetTestStateCompleted
                exit 0
        fi
fi
