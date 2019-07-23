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
if [[ $? -eq 0 ]]; then
    LogMsg "ERROR: Install sshpass failed"
    UpdateSummary "ERROR: Install sshpass failed"
    SetTestStateFailed
    exit 1
fi

# SCP server bin to hv server
sshpass -p 123qweP scp -o StrictHostKeyChecking=no /root/server root@$hv_server:/tmp/
sshpass -p 123qweP ssh -o StrictHostKeyChecking=no /root/server root@$hv_server "chmod a+x /tmp/server"
# TODO. HERE. Test its scp result

# Execute it in ESXi Host as a server
sshpass -p 123qweP ssh -o StrictHostKeyChecking=no root@$hv_server "/tmp/server"

# Execute it in a VM as a guest
/root/client 2
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
