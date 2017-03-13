#!/bin/bash

###############################################################################
##
## Description:
##   This script checks file /etc/pam.d/vmtoolsd.
##   There should not have pam_unix2.so included.
##
###############################################################################
##
## Revision:
## v1.0 - xiaofwan - 12/29/2016 - Draft script for case ESX-OVT-004.
## v1.1 - xiaofwan - 1/25/2016 - Skip this test case in RHEL-6.x environment.
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
UpdateSummary "$(uname -a)"

if [[ $DISTRO == "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi
cat /etc/pam.d/vmtoolsd | grep pam_unix2.so
if [[ $? == 0 ]]; then
    LogMsg "Test Failed. There's pam_unix2.so file in vmtoolsd."
    UpdateSummary "Test Failed. There's pam_unix2.so file in vmtoolsd."
    SetTestStateFailed
else
    LogMsg "Test Successfully. There's NO pam_unix2.so file in vmtoolsd."
    UpdateSummary "Test Successfully. There's NO pam_unix2.so file in vmtoolsd."
    SetTestStateCompleted
fi
