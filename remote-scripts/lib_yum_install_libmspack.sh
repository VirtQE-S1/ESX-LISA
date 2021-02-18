#!/bin/bash


########################################################################################
##	Description:
##		This script install the libmspack.
##   	The libmspack should be installed with yum command successfully.
##	Revision:
##  v1.0 - ldu - 03/12/2019 - Draft script for case ESX-lib-002.
########################################################################################


# Source utils.sh
dos2unix utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


########################################################################################
## Main
########################################################################################
if [[ $DISTRO == "redhat_6" ]]; then
        SetTestStateSkipped
        exit
fi


yum erase -y libmspack
version=$(rpm -qa libmspack)
LogMsg "$version"
if [ -n "$version" ]; then
        LogMsg "ERROR: unintall the libmspack Failed"
        UpdateSummary "ERROR: unintall the libmspack Failed"
        SetTestStateAborted
        exit 1
else
        yum -y install libmspack
        version=$(rpm -qa libmspack)
        if [ -n "$version" ]; then
                LogMsg "INFO: libmspack installed successfully."
                UpdateSummary "INFO: libmspack installed successfully."
                SetTestStateCompleted
                exit 0
        else
                LogMsg "ERROR: libmspack installed Failed."
                UpdateSummary "ERROR: libmspack installed Failed."
                SetTestStateFailed
                exit 1
        fi
fi
