#!/bin/bash


########################################################################################
##	Description:
##   	The libmspack should be uninstalled with yum command successfully.
##	Revision:
##  v1.0 - ldu - 03/12/2019 - Draft script for case ESX-lib-003.
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


version=$(rpm -qa libmspack)
LogMsg "$version"
if [ -n "$version" ]; then
		yum -y erase libmspack
        version=$(rpm -qa libmspack)
        if [ -n "$version" ]; then
                LogMsg "ERROR: libmspack uninstalled Failed."
                UpdateSummary "ERROR: libmspack uninstalled Failed."
                SetTestStateFailed
                exit 1
        else
                LogMsg "INFO: libmspack uninstalled successfully."
                UpdateSummary "INFO: libmspack uninstalled successfully."
                SetTestStateCompleted
                exit 0
        fi
else
        LogMsg "ERROR: libmspack isn't installed."
        UpdateSummary "ERROR: libmspack isn't installed."
fi
