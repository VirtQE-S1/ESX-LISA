#!/bin/bash

###############################################################################
##
## Description:
##   This script install the libmspack.
##   The libmspack should be installed with yum command successfully.
##
###############################################################################
##
## Revision:
##  v1.0 - ldu - 03/12/2019 - Draft script for case ESX-lib-002.
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

yum erase -y libmspack
version=$(rpm -qa libmspack)
LogMsg "$version"
if [ -n "$version" ]; then
        LogMsg "unintall the libmspack Failed"
        UpdateSummary "Test Failed. unintall the libmspack Failed."
        SetTestStateAborted
        exit 1
else
        yum -y install libmspack
        version=$(rpm -qa libmspack)
        if [ -n "$version" ]; then
                LogMsg "libmspack installed successfully."
                UpdateSummary " libmspack installed successfully."
                SetTestStateCompleted
                exit 0
        else
                LogMsg "libmspack installed Failed."
                UpdateSummary " libmspack installed Failed."
                SetTestStateFailed
                exit 1
        fi
fi
