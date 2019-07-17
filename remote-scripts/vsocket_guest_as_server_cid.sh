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
    echo "Error: unable to source utils.sh."
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


########################################################################################
## Main script body
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
sshpass -p 123qweP scp -o StrictHostKeyChecking=no /root/client root@$hv_server:/tmp/
# TODO. HERE. Test its scp result

# Execute it in VM as a server
./root/server &
ports=`cat /root/port.txt`
LogMsg "DEBUG: ports: $ports"
UpdateSummary "DEBUG: ports: $ports"

# Execute it in hv server as a guest
sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "./tmp/client $ports"
if [[ $? -eq 0 ]]; then
    LogMsg "INFO: ESXi Host as a guest communicates with VM as a server well"
    UpdateSummary "INFO: ESXi Host as a guest communicates with VM as a server well"
    SetTestStateCompleted
    exit 0
else
    LogMsg "ERROR: ESXi Host as a guest communicates with VM as a server well"
    UpdateSummary "ERROR: ESXi Host as a guest communicates with VM as a server well"
    SetTestStateFailed
    exit 1
fi
