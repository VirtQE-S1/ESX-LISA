#!/bin/bash


###############################################################################
##
## Description:
## 	Test scrip test_pktgen.sh in VM
##
## Revision:
## 	v1.0.0 - boyang - 03/09/2018 - Build script
## 	v1.0.1 - boyang - 05/14/2019 - Get VM's IP dynamically
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


#######################################################################
#
# Main script body
#
#######################################################################


# Get NIC interface
nic=`ls /sys/class/net | grep ^e[tn][hosp]`
LogMsg "DEBUG: nic: $nic"
UpdateSummary "DEBUG: nic: $nic"


# NIC hardware address
hwadd=`cat /sys/class/net/$nic/address`
LogMsg "INFO: hwadd is $hwadd"
UpdateSummary "INFO: hwadd is $hwadd"


# NIC IP address
ipadd=`ip -f inet add | grep $nic | grep inet | awk '{print $2}' | awk -F "/" '{print $1}'`
if [ "x$ipadd" -eq "x" ]
    then
	LogMsg "ERROR: Get VM's IP failed"
	UpdateSummary "ERROR: Get VM's IP failed"
	SetTestStateAborted
        exit 1
fi
LogMsg "INFO: ipadd is $ipadd"
UpdateSummary "INFO: ipadd is $ipadd"


LogMsg "INFO: Will modprobe pktgen"
UpdateSummary "INFO: Will modprobe pktgen"
modprobe pktgen
if [ $? -ne 0 ]; then
    LogMsg "ERROR: Before RHEL8.1.0 DISTRO, modprobe pktgen directlly. After RHEL8.1.0, it has been moved to kernel self test package, should install kernel-module-internal package from brew"
    UpdateSummary "ERROR: Before RHEL8.1.0 DISTRO, modprobe pktgen directlly. After RHEL8.1.0, it has been moved to kernel self test package, should install kernel-module-internal package from brew"
    
    LogMsg "INFO: Try to install a kernel-module-internal in RHEL-8.1.0 or later"
    UpdateSummary "INFO: Try to install a kernel-module-internal in RHEL-8.1.0 or later"

    #//download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/kernel/4.18.0/94.el8/x86_64/kernel-modules-internal-4.18.0-94.el8.x86_64.rpm
    url_pre="http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/kernel"
    ver=`uname -r | awk -F "-" {'print $1'}`
    rel1=`uname -r | awk -F "-" {'print $2'} | awk -F "." {'print $1'}`
    rel2=`uname -r | awk -F "-" {'print $2'} | awk -F "." {'print $2'}`
    arch=`uname -r | awk -F "-" {'print $2'} | awk -F "." {'print $3'}`
    url="${url_pre}/${ver}/${rel1}.${rel2}/${arch}/kernel-modules-internal-${ver}-${rel1}.${rel2}.${arch}.rpm"
    LogMsg "DEBUG: url: $url"
    UpdateSummary "DEBUG: url: $url"

    yum -y install $url
    if [ $? -ne 0 ]; then
	LogMsg "ERROR: Try to install kernel-module-internal failed"        
	UpdateSummary "ERROR: Try to install kernel-module-internal failed"        
        exit 1
    fi
fi 


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
# Each CPU has own thread. One CPU exammple. Add the name the guest nic, such as eth0
PGDEV=/proc/net/pktgen/kpktgend_0
LogMsg "INFO: Removing all devices"
UpdateSummary "INFO: Removing all devices"
pgset "rem_device_all"

# Change to the name of nic
LogMsg "INFO: Adding $nic"
UpdateSummary "INFO: Adding $nic"
pgset "add_device $nic"

# Setting max_before_softirq
LogMsg "INFO: Setting max_before_softirq 10000"
UpdateSummary "INFO: Setting max_before_softirq 10000"
pgset "max_before_softirq 10000"

# Device config
# Delay 0 means maximum speed.
CLONE_SKB="clone_skb 1000000"

# NIC adds 4 bytes CRC
PKT_SIZE="pkt_size 60"

# COUNT 0 means forever
COUNT="count 10000000"
DELAY="delay 0"
PGDEV=/proc/net/pktgen/$nic

LogMsg "INFO: Configuring $PGDEV"
UpdateSummary "INFO: Configuring $PGDEV"
pgset "$COUNT"
pgset "$CLONE_SKB"
pgset "$PKT_SIZE"
pgset "$DELAY"
pgset "dst $ipadd" # IP address of NIC you want to test, such as eth0.
pgset "dst_mac $hwadd" # MAC address of the name of NIC you want to test, such as eth0.


# Time to run
PGDEV=/proc/net/pktgen/pgctrl
LogMsg "INFO: Running... ctrl^C to stop"
UpdateSummary "INFO: Running... ctrl^C to stop"
pgset "start"
LogMsg "INFO: Done"
UpdateSummary "INFO: Done"

LogMsg "INFO: Result is stored in /proc/net/pktgen/$nic"
UpdateSummary "INFO: Result is stored in /proc/net/pktgen/$nic"


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

