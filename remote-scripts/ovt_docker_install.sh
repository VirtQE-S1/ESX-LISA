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

#Install docker CE package
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce
systemctl enable docker
systemctl start docker
if [[ $? == 0 ]]; then
    LogMsg "Test Successfully. Docker service start successfully"
    UpdateSummary "Test Successfully. Docker service start successfully."
else
    LogMsg "Test failed. Docker service start failed."
    UpdateSummary "Test Failed.  Docker service start failed."
    SetTestStateAborted
    exit 1
fi 

service=$(systemctl status docker |grep running -c)

if [ "$service" = "1" ]; then
  LogMsg $service
  UpdateSummary "Test Successfully. service docker is running."

else
  LogMsg "Info : The service docker is not running'"
  UpdateSummary "Test failed. The service docker is not running."
  SetTestStateAborted
  exit 1
fi

#start a network container
docker run -P -d nginx:latest
if [[ $? == 0 ]]; then
    LogMsg "Test Successfully. The container run successfully"
    UpdateSummary "Test Successfully. The container run successfully."
    SetTestStateCompleted
    exit 0
else
    LogMsg "Test failed. The container web app run failed."
    UpdateSummary "Test Failed. The container web app run failed."
    #Run another image
    docker run -d -P --name web training/webapp python app.py
    if [[ $? == 0 ]]; then
        LogMsg "Test Successfully. The container run successfully"
        UpdateSummary "Test Successfully. The container run successfully."
        SetTestStateCompleted
        exit 0
    else
        SetTestStateFailed
        exit 1
    fi
fi
