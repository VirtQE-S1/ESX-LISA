#!/bin/bash


###############################################################################
##
## Description:
## 	Test scrip test_pktgen.sh in VM
##
## Revision:
## 	v1.0.0 - boyang - 03/09/2018 - Build script
##
###############################################################################


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


#######################################################################
#
# Main script body
#
#######################################################################


# Get NIC interface
nic=`ls /sys/class/net | grep ^e[tn][hosp]`

# NIC hardware address
hwadd=`cat /sys/class/net/$nic/address`
LogMsg "hwadd is $hwadd"
UpdateSummary "hwadd is $hwadd"

# NIC IP address
ipadd=`ip -f inet add |grep eth0 |grep inet | awk '{print $2}' | awk -F "/" '{print $1}'`
if [ "x$ipadd" -eq "x" ]
    then
		LogMsg "hwadd is $hwadd"
		UpdateSummary "hwadd is $hwadd"
		SetTestStateAborted
        exit 1
fi
LogMsg "ipadd is $ipadd"
UpdateSummary "ipadd is $ipadd"


LogMsg "modprobe pktgen"
UpdateSummary "modprobe pktgen"
modprobe pktgen


function pgset() {
    local result

    echo $1 > $PGDEV

    result=`cat $PGDEV | fgrep "Result: OK:"`
    if [ "$result" = "" ]; then
         cat $PGDEV | fgrep Result:
    fi
}


function pg() {
    echo inject > $PGDEV
    cat $PGDEV
}


#
# Config Start Here
#

# Thread config
# Each CPU has own thread. One CPU exammple. We add the name the guest nic, such as eth0
PGDEV=/proc/net/pktgen/kpktgend_0
LogMsg "Removing all devices"
UpdateSummary "Removing all devices"
pgset "rem_device_all"

# Change to the name of nic
LogMsg "Adding $nic"
UpdateSummary "Adding $nic"
pgset "add_device $nic"

# Setting max_before_softirq
LogMsg "Setting max_before_softirq 10000"
UpdateSummary "Setting max_before_softirq 10000"
pgset "max_before_softirq 10000"

# Device config
# Delay 0 means maximum speed.
CLONE_SKB="clone_skb 1000000"

# NIC adds 4 bytes CRC
PKT_SIZE="pkt_size 60"

# COUNT 0 means forever
# COUNT="count 0"
COUNT="count 10000000"
DELAY="delay 0"
PGDEV=/proc/net/pktgen/$nic
LogMsg "Configuring $PGDEV"
UpdateSummary "Configuring $PGDEV"
pgset "$COUNT"
pgset "$CLONE_SKB"
pgset "$PKT_SIZE"
pgset "$DELAY"
pgset "dst $ipadd" # IP address of NIC you want to test, such as eth0.
pgset "dst_mac $hwadd" # MAC address of the name of NIC you want to test, such as eth0.


# Time to run
PGDEV=/proc/net/pktgen/pgctrl
LogMsg "Running... ctrl^C to stop"
UpdateSummary "Running... ctrl^C to stop"
pgset "start"
LogMsg "Done"
UpdateSummary "Done"
LogMsg "Result is stored in /proc/net/pktgen/$nic"
UpdateSummary "Result is stored in /proc/net/pktgen/$nic"


# Check the result
cat /proc/net/pktgen/$nic | grep "Result: OK"
if [ $? -eq 0 ]
    then
		LogMsg "PASS: case passed"
		UpdateSummary "PASS: case passed"
		SetTestStateCompleted
        exit 0
else
	LogMsg "FAIL: cases failed"
	UpdateSummary "FAIL: cases failed"
	SetTestStateFailed
	exit 1
fi
