 
#!/bin/bash

###############################################################################
##
## Description:
##   This script checks
##  Take snapshot after install container in guest.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 23/07/2017 - Take snapshot after install container in guest.
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

#Install podman package

yum install podman -y
if [[ $? == 0 ]]; then
    LogMsg "Test Successfully. podman installed successfully"
    UpdateSummary "Test Successfully.podman installed successfully."
else
    LogMsg "Test failed.podman installed failed."
    UpdateSummary "Test Failed.  podman installed failed."
    SetTestStateAborted
    exit 1
fi 

#start a network container
podman run -P -d nginx:latest
if [[ $? == 0 ]]; then
    LogMsg "Test Successfully. The container run successfully"
    UpdateSummary "Test Successfully. The container run successfully."
    SetTestStateCompleted
    exit 0
else
    LogMsg "Test failed. The container web app run failed."
    UpdateSummary "Test Failed. The container web app run failed."
    SetTestStateFailed
    exit 1
fi


