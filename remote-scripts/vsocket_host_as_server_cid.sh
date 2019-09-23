#!/bin/bash


########################################################################################
## Description:
##	    A VM as a Client communicates to a ESXi Host as a Server with CID
##
## Revision:
##  	v1.0.0 - boyang - 06/12/2019 - Draft script
##  	v1.0.1 - boyang - 06/12/2019 - Setenforce 0 when VM as a Client
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
if [ ! $hv_server ]; then
    LogMsg "ERROR: Can't get hv server IP or it is null"
    UpdateSummary "ERROR: Can't get hv server IP or it is null"
    SetTestStateAborted
    exit 1
else
       ping $hv_server -c 1 -W 3
       if [ $? -ne 0 ]; then
            LogMsg "ERROR: Can't ping this IP - $hv_server"
            UpdateSummary "ERROR: Can't ping this IP - $hv_server"
            SetTestStateAborted
            exit 1
       fi
fi

# Install sshpass with git
LogMsg "INFO: Will install sshpass in $DISTRO"
UpdateSummary "INFO: Will install sshpass in $DISTRO"
if [ "$DISTRO" == "redhat_7" ]; then
    url=http://download.eng.bos.redhat.com/brewroot/vol/rhel-7/packages/sshpass/1.06/2.el7/x86_64/sshpass-1.06-2.el7.x86_64.rpm
elif [ "$DISTRO" == "redhat_8" ]; then
    url=http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/sshpass/1.06/2.el8/x86_64/sshpass-1.06-2.el8.x86_64.rpm
else
    url=http://download.eng.bos.redhat.com/brewroot/vol/rhel-6/packages/sshpass/1.06/1.el6/x86_64/sshpass-1.06-1.el6.x86_64.rpm
fi
yum install -y $url


# SCP server bin to hv server
LogMsg "INFO: SCP server file to $hv_server"
UpdateSummary "INFO: SCP server file to $hv_server"
sshpass -p 123qweP scp -o StrictHostKeyChecking=no /root/server root@$hv_server:/tmp/

# CHMOD server bin in hv server
LogMsg "INFO: CHMOD server file in $hv_server"
UpdateSummary "INFO: CHMOD server file in $hv_server"
sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "chmod a+x /tmp/server"

# Execute it in ESXi Host as a server
LogMsg "INFO: Execute server file in Host"
UpdateSummary "INFO: Execute server file in Host"
sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "pkill -9 server" &
sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "cd /tmp/ && ./server" &
ports=`sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "cat /tmp/port.txt"`
LogMsg "DEBUG: ports: $ports"
UpdateSummary "DEBUG: ports: $ports"

sleep 6

# Setenforce 0
setenforce 0

# Execute it in a VM as a guest
LogMsg "INFO: CHMOD client file in VM"
UpdateSummary "INFO: CHMOD client file in VM"
chmod a+x /root/client
pkill -9 client
sleep 1
/root/client $ports
if [[ $? -eq 0 ]]; then
    LogMsg "INFO: ESXi Host as a server communicates with VM as a clinet well"
    UpdateSummary "INFO: ESXi Host as a server communicates with VM as a clinet well"
    SetTestStateCompleted
    sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "pkill -9 server" &
    pkill -9 client
    exit 0
else
    LogMsg "ERROR: ESXi Host as a server communicates with VM as a clinet failed"
    UpdateSummary "ERROR: ESXi Host as a server communicates with VM as a clinet failed"
    SetTestStateFailed
    sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "pkill -9 server" &
    pkill -9 client
    exit 1
fi
