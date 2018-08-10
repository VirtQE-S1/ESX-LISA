#!/bin/bash

###############################################################################
##
## Description:
##  Test the guest with IO stress tool iozone.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 8/06/2018 - Build the script
##
###############################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants.sh to get all paramters from XML <testParams>
. constants.sh || {
    echo "Error: unable to source constants.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


###############################################################################
##
## Main
##
###############################################################################
# Install required package for compil iozone.Download iozon form offical website
yum install make gcc -y
if [ ! "$?" -eq 0 ]; then
    LogMsg "ERROR: YUM install make, gcc failed"
    UpdateSummary "ERROR: YUM install make, gcc failed"
    SetTestStateAborted
    exit 1
fi

wget http://www.iozone.org/src/current/iozone3_482.tar
if [ ! "$?" -eq 0 ]; then
    LogMsg "ERROR: WGET failed as iozone address is unavailable"
    UpdateSummary "ERROR: WGET failed as iozone address is unavailable"
    SetTestStateAborted
    exit 1
fi

tar xvf iozone3_482.tar
cd /root/iozone3_482/src/current
make linux
if [ ! "$?" -eq 0 ]; then
    LogMsg "Test Failed.iozone install failed."
    UpdateSummary "Test failed.iozone install failed."
    SetTestStateAborted
    exit 1
else
    LogMsg " iozone install  successfully."
    UpdateSummary "iozone install  successfully."
fi

# Execute IOZONE
./iozone -a -g 4G -n 1024M -s 2048M -f /root/io_file -Rab /root/aiozon.wks
if [ ! "$?" -eq 0 ]; then
    LogMsg "Test Failed. iozone run failed."
    UpdateSummary "Test failed.iozone run failed."
    SetTestStateFailed
    exit 1
else
    LogMsg " iozone run successfully."
    UpdateSummary "iozone run successfully."
    SetTestStateCompleted
    exit 0
fi
