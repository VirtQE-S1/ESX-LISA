#!/bin/bash

###############################################################################
##
## Description:
##   This script unintall the libmspack.
##   The libmspack should be uninstalled successfully.
##
###############################################################################
##
## Revision:
##  v1.0 - ldu - 03/12/2019 - Draft script for case ESX-lib-003.
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

version=$(rpm -qa libmspack)
LogMsg "$version"
if [ -n "$version" ]; then
        yum erase -y libmspack
        version=$(rpm -qa libmspack)
        if [ -n "$version" ]; then
                LogMsg "Unistall the libmspack Failed"
                UpdateSummary "Test Failed. Unistall the libmspack Failed."
                SetTestStateFailed
                exit 1
        else
                LogMsg "Unistall the libmspack"
                UpdateSummary "Test Successfully. Unistall the libmspack."
                SetTestStateCompleted
                exit 0
        fi
else
        LogMsg "the libmspack not installed"
        UpdateSummary "Test Failed. libmspack not installed."
        SetTestStateAborted
        exit 1
fi
