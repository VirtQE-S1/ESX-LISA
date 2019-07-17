#!/bin/bash


########################################################################################
## Description:
##	    A VM as a Server communicates to a ESXi Host as a Client with CID
##
## Revision:
##  	v1.0.0 - boyang - 06/12/2019 - Draft script
########################################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


########################################################################################
##
## Main script body
##
########################################################################################

# Get target Host IP where VM installed
hv_server=$1
# TODO. HERE. Test $1

# Install sshpass with git
git clone git://github.com/kevinburke/sshpass.git
cd sshpass
./configure
make && make install
# TODO. HERE. Test instalaltion status

# SCP server bin to hv server
sshpass -p 123qweP scp -o StrictHostKeyChecking=no /root/server root@$hv_server:/tmp/
# TODO. HERE. Test its scp result

# Execute it in ESXi Host as a server
sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "./tmp/server"

# Execute it in a VM as a guest
./root/client 2
if [[ $? -eq 0 ]]; then
    LogMsg "INFO: ESXi Host as a server communicates with VM as a clinet well"
    UpdateSummary "INFO: ESXi Host as a server communicates with VM as a clinet well"
    SetTestStateCompleted
    exit 0
else
    LogMsg "ERROR: ESXi Host as a server communicates with VM as a clinet well"
    UpdateSummary "ERROR: ESXi Host as a server communicates with VM as a clinet well"
    SetTestStateFailed
    exit 1
fi
