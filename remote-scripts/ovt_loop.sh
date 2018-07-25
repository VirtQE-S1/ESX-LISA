#!/bin/bash

###############################################################################
##
## Description:
##   This script checks
##  Take snapshot after deadlock condiation.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 23/07/2017 - Take snapshot after deadlock condiation.
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

#Run a loop scripts
while true; do
    UpdateSummary "DEBUG: Will echo hello word"
    LogMsg "DEBUG: Will echo hello word"
    echo "Hello World" >> /srv/node/partition1/hello
done
