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

if [[ $DISTRO == "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi


while true; do
    UpdateSummary "DEBUG: Will echo hello word"
    LogMsg "DEBUG: Will echo hello word"
    echo "Hello World" >> /srv/node/partition1/hello
done
