#!/bin/bash

###############################################################################
##
## Description:
##   This script checks vmtoolsd status.
##   The vmtoolsd status should be running.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 03/07/2017 - Draft script for case ESX-OVT-002.
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

if [[ $DISTRO != "redhat_7" ]]; then
    SetTestStateSkipped
    exit
fi

service=$(systemctl status vmtoolsd |grep running -c)

if [ "$service" = "1" ]; then
  LogMsg $service
  UpdateSummary "Test Successfully. service vmtoolsd is running."
  SetTestStateCompleted
  exit 0
else
  LogMsg "Info : The service vmtoolsd is not running'"
  UpdateSummary "Test Successfully. The service vmtoolsd is not running."
  SetTestStateFailed
  exit 1
fi
