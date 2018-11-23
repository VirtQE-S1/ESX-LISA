##   Use DPDK KNI module to let DPDK adapter use kernel tools (ifconfig, ethtool)
##
###############################################################################
##
## Revision:
## v1.0 - ruqin - 7/18/2017 - Building the script.
##
###############################################################################

: '
        <test>
            <testName>dpdk_kni</testName>
            <testID>ESX-DPDK-004</testID>
            <testScript>dpdk_kni_4.sh</testScript>
            <files>remote-scripts/dpdk_kni_4.sh</files>
            <files>remote-scripts/utils.sh</files>
            <RevertDefaultSnapshot>False</RevertDefaultSnapshot>
            <testParams>
                <param>TC_COVERED=RHEL-136473</param>
            </testParams>
            <timeout>240</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
        </test>

'


dos2unix utils.sh

#
# Source utils.sh
#
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

#
# Source constants file and initialize most common variables
#
UtilsInit

###############################################################################
##
## Put your test script here
## NOTES:
## 1. Please use LogMsg to output log to terminal.
## 2. Please use UpdateSummary to output log to summary.log file.
## 3. Please use SetTestStateFailed, SetTestStateAborted, SetTestStateCompleted,
##    and SetTestStateRunning to mark test status.
##
##################################################

# Prepare Start KNI


# Printout current Guest OS
GetDistro
LogMsg $DISTRO
# This case cannot run on rhel6
if [ "$DISTRO" == "redhat_6" ]
then
    SetTestStateSkipped
    LogMsg "Not support rhel6"
    exit 1
fi


# Apply environment settings and insert kni module
source /etc/profile.d/dpdk.sh
insmod "$RTE_SDK/$RTE_TARGET/kmod/rte_kni.ko"


# Compile KNI example code
cd "$RTE_SDK/examples/kni" || exit 1
make
if [ ! "$?" -eq 0 ]
then
    LogMsg "KNI compile Failed"
    SetTestStateAborted
    exit 1
fi
cd build || exit 1


# Create virtual NIC with KNI
nohup ./kni -l 1-3 -n 4 -- -P -p 0x1 --config="(0,1,2)" &


# Setup new nic
systemctl restart NetworkManager
nmcli con add con-name vEth0 ifname vEth0 type Ethernet

if [ ! "$?" -eq 0 ]
then
    LogMsg "KNI connection Failed"
    SetTestStateFailed
    exit 1
fi
systemctl restart NetworkManager


# Test New Network Adapter
sleep 6


# Get SSH Server IP address dnd NIC
Server_IP=$(echo "$SSH_CONNECTION"| awk '{print $3}')

LogMsg "$Server_IP"

Server_Adapter=$(ip a|grep "$Server_IP"| awk '{print $(NF)}')


##################################################
# Test Network Connection


# Turn down ssh nic to make sure only have one NIC
nmcli con down $Server_Adapter


# print current nics status
ip a


# DPDK KNI device should be vEth0 at default
# This ping is test ESX host IP connectivity with current VM, Host IP addr may change in the furture
ping -I vEth0 -c 3 10.73.196.97
ping -I vEth0 -c 3 10.73.196.97 | grep ttl > /dev/null


# Record ping results and up old SSH nic
status=$?
# Turn down vEth0
nmcli con down vEth0
nmcli con up $Server_Adapter


# Check status and record results
if [ "$status" -eq 0 ]
then
    LogMsg "KNI is working"
    UpdateSummary "KNI is working"
    sleep 1
    LogMsg "Start to Close KNI"
    # Close KNI
    ps aux | grep "./kni -l 1-3 -n 4 -- -P -p 0x1" | grep -v grep | awk '{print $2}' | xargs kill
    SetTestStateCompleted
    exit 0
else
    LogMsg "KNI is not working or ESXi Host server IP address is changed"
    UpdateSummary "KNI is not working or ESXi Host server IP address is changed"
    SetTestStateFailed
    exit 1
fi
