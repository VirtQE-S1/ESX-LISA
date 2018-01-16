#!/bin/bash

###############################################################################
##
## Description:
##   Add a alias for testuser by vgauth
##
###############################################################################
##
## Revision:
## v1.0 - boyang - 01/11/2018 - Draft script for case ESX-OVT-027
##
###############################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

. constants.sh || {
    echo "Error: unable to source constants.sh!"
    exit 1
}

# Source constants file and initialize most common variables
UtilsInit

###############################################################################
##
## Main Body
##
###############################################################################

ovt_cert_pem="/root/ovt_cert.pem"

#
# Start the testing
#
if [[ $DISTRO != "redhat_7" ]]; then
    SetTestStateSkipped
    exit
fi

#
# Add a testuser
#
useradd testuser
if [ "$?" != "0" ];then
    LogMsg "ABORTED: adding testuser fails"
    UpdateSummary "ABORTED: adding testuser fails"
    SetTestStateAborted
    exit 1
else
    LogMsg "Adding testuser successfully"
    UpdateSummary "Adding testuser successfully"
fi


#
# Confirm ovt_cert.pem esxits
#
if [ ! -f $ovt_cert_pem ];then
    LogMsg "ABORTED: PEM file doesn't exists"
    UpdateSummary "ABORTED: PEM file doesn't exists"
    SetTestStateAborted
    exit 1
fi

#
# Add alias to testuser
#
vmware-vgauth-cmd add --verbose --username=testuser --file=/root/ovt_cert.pem --subject=defaultsubject --comment=defaultcomment
if [ "$?" != "0" ];then
    LogMsg "ABORTED: adding alias fails"
    UpdateSummary "ABORTED: adding alias fails"
    SetTestStateFailed
    exit 1
else
    LogMsg "PASS: Adding alias successfully"
    UpdateSummary "PASS: Adding alias successfully"
	SetTestStateCompleted
	exit 0
fi

